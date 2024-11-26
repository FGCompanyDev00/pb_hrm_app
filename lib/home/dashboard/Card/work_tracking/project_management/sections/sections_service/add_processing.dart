// add_processing.dart

import 'dart:convert';
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For Image Picker
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart'; // For MIME type checking
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_processing_members.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http_parser/http_parser.dart'; // For MediaType

class AddProcessingPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const AddProcessingPage({
    super.key,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  _AddProcessingPageState createState() => _AddProcessingPageState();
}

class _AddProcessingPageState extends State<AddProcessingPage> {
  final _formKey = GlobalKey<FormState>();

  // Processing Data
  String title = '';
  String description = '';
  String status = 'Processing';
  String statusId = '0a8d93f0-1c05-42b2-8e56-984a578ef077';
  DateTime? fromDate;
  DateTime? toDate;

  // Members
  List<Map<String, dynamic>> selectedMembers = [];

  bool _isLoading = false;

  // Image File
  File? _selectedImage;

  final Map<String, String> _statusMap = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  @override
  void initState() {
    super.initState();
    print('[_AddProcessingPageState] Initializing with projectId: ${widget.projectId}, baseUrl: ${widget.baseUrl}');
    // Initialize dates as null to display placeholders initially
    fromDate = null;
    toDate = null;
  }

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

  Future<void> _selectFromDate() async {
    final DateTime initialDate = fromDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        fromDate = picked;
      });
    }
  }

  Future<void> _selectToDate() async {
    final DateTime initialDate = toDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        toDate = picked;
      });
    }
  }

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

  Future<void> _addProcessingItem() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (fromDate == null || toDate == null) {
      _showAlertDialog(
        title: 'Invalid Dates',
        content: 'Please select both start and end dates.',
        isError: true,
      );
      return;
    }

    if (selectedMembers.isEmpty) {
      _showAlertDialog(
        title: 'No Members Selected',
        content: 'Please select at least one member.',
        isError: true,
      );
      return;
    }

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
      var uri = Uri.parse('${widget.baseUrl}/api/work-tracking/meeting/insert');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['project_id'] = widget.projectId;
      request.fields['title'] = title;
      request.fields['descriptions'] = description;
      request.fields['status_id'] = _statusMap[status]!;
      request.fields['fromdate'] = DateFormat('yyyy-MM-dd').format(fromDate!);
      request.fields['todate'] = DateFormat('yyyy-MM-dd').format(toDate!);

      List<Map<String, String>> membersDetails = selectedMembers
          .map((member) => {"employee_id": member['employee_id'].toString()})
          .toList();
      request.fields['membersDetails'] = jsonEncode(membersDetails);

      if (_selectedImage != null) {
        if (await _selectedImage!.exists()) {
          final mimeType = lookupMimeType(_selectedImage!.path) ?? 'application/octet-stream';
          final mimeTypeData = mimeType.split('/');

          request.files.add(
            await http.MultipartFile.fromPath(
              'file_name', // Ensure this matches the API's expected field name
              _selectedImage!.path,
              contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
            ),
          );
        } else {
          _showAlertDialog(
            title: 'File Error',
            content: 'Selected image file does not exist.',
            isError: true,
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Log request details for debugging
      print('Sending request to: ${uri.toString()}');
      print('Request Fields: ${request.fields}');
      print('Number of files: ${request.files.length}');

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showAlertDialog(
          title: 'Success',
          content: 'Processing item added successfully.',
          isError: false,
          onOk: () {
            Navigator.pop(context, true);
          },
        );
      } else {
        String errorMessage = 'Failed to add processing item.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showAlertDialog(title: 'Error', content: errorMessage, isError: true);
      }
    } on SocketException catch (e) {
      _showAlertDialog(
        title: 'Network Error',
        content: 'Please check your internet connection and try again.',
        isError: true,
      );
      print('SocketException: $e');
    } on HttpException catch (e) {
      _showAlertDialog(
        title: 'HTTP Error',
        content: 'Could not connect to the server. Please try again later.',
        isError: true,
      );
      print('HttpException: $e');
    } on FormatException catch (e) {
      _showAlertDialog(
        title: 'Data Format Error',
        content: 'Unexpected data format received from the server.',
        isError: true,
      );
      print('FormatException: $e');
    } catch (e) {
      _showAlertDialog(
        title: 'Unexpected Error',
        content: 'An unexpected error occurred: $e',
        isError: true,
      );
      print('Unexpected error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showAlertDialog({
    required String title,
    required String content,
    required bool isError,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                Navigator.of(context).pop();
                if (!isError &&
                    (title.toLowerCase().contains('success') ||
                        title.toLowerCase().contains('added'))) {
                  if (onOk != null) {
                    onOk();
                  }
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSelectMembers() async {
    print('[_AddProcessingPageState] Navigating to SelectProcessingMembersPage with projectId: ${widget.projectId}');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectProcessingMembersPage(
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
      print('[_AddProcessingPageState] Members selected: ${selectedMembers.map((m) => m['employee_id']).toList()}');
    }
  }

  Widget _buildSelectedMembers() {
    if (selectedMembers.isEmpty) return const Text('No members selected.');

    int displayCount = selectedMembers.length > 5 ? 5 : selectedMembers.length;
    List<Widget> avatars = [];

    for (int i = 0; i < displayCount; i++) {
      avatars.add(
        Positioned(
          left: i * 24.0,
          child: CircleAvatar(
            backgroundImage: selectedMembers[i]['image_url'] != null && selectedMembers[i]['image_url'].isNotEmpty
                ? NetworkImage(selectedMembers[i]['image_url'])
                : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
      child: Stack(
        children: avatars,
      ),
    );
  }

  Widget _buildAddButton(double buttonWidth) {
    return SizedBox(
      width: buttonWidth = 160,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _addProcessingItem, // Disable when loading
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Add',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDBB342), // #DBB342
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildDateInput({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label.isNotEmpty ? label : null,
            hintText: selectedDate == null ? 'dd/mm/yyyy' : '',
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Image.asset(
                'assets/calendar-icon.png',
                width: 22,
                height: 22,
                color: Colors.grey,
              ),
            ),
          ),
          controller: TextEditingController(
            text: selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate) : '',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required.';
            }
            return null;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    // Determine screen size for responsiveness
    final Size screenSize = MediaQuery.of(context).size;

    double horizontalPadding = screenSize.width * 0.04; // 5% of screen width
    double verticalPadding = screenSize.height * 0.05; // 5% of screen height
    horizontalPadding = horizontalPadding < 16.0 ? 16.0 : horizontalPadding;

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
          'Add Processing Item',
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
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18.0),
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
                      child: _buildAddButton(100), // Fixed width for consistency
                    ),
                    const SizedBox(height: 10),
                    // Title Section
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
                          borderRadius: BorderRadius.all(Radius.circular(8.0)), // Curved border
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
                    // Status Dropdown and Upload Image Button Row
                    Row(
                      children: [
                        Expanded( // Wrap the Status Dropdown with Expanded to prevent overflow
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
                                value: status, // Current status value
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(8.0)), // Curved border
                                  ),
                                ),
                                items: ['Processing', 'Pending', 'Finished', 'Error']
                                    .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: _getStatusColor(value), // Method to get color based on status
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
                        Expanded( // Wrap the Upload Image button with Expanded to take the remaining space
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
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _pickImage, // Disable when loading
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 18.0,
                                      horizontal: MediaQuery.of(context).size.width < 400 ? 44 : 44,
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
                    const SizedBox(height: 18),
                    // Start Date and End Date
                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Date',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildDateInput(
                                label: '',
                                selectedDate: fromDate,
                                onTap: _selectFromDate,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // End Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Date',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildDateInput(
                                label: '',
                                selectedDate: toDate,
                                onTap: _selectToDate,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Add People and Selected Members
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // + Add People Button
                        SizedBox(
                          width: constraints.maxWidth * 0.45,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _navigateToSelectMembers, // Disable when loading
                            icon: const Icon(Icons.person_add, color: Colors.white),
                            label: const Text(
                              'Add People',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ),
                        // Selected Members Display
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
                          borderRadius: BorderRadius.all(Radius.circular(8.0)), // Curved border
                        ),
                      ),
                      maxLines: 4,
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
