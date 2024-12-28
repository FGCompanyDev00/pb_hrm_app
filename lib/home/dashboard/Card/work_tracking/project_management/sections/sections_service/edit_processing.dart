import 'dart:convert';
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class UpdateProcessingPage extends StatefulWidget {
  final String meetingId;
  final String projectId;
  final String baseUrl;

  const UpdateProcessingPage({
    super.key,
    required this.meetingId,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  _UpdateProcessingPageState createState() => _UpdateProcessingPageState();
}

class _UpdateProcessingPageState extends State<UpdateProcessingPage> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> selectedMembers = [];

  // Original Data
  String originalTitle = '';
  String originalDescription = '';
  String originalStatus = 'Processing';
  String originalStatusId = '0a8d93f0-1c05-42b2-8e56-984a578ef077';
  DateTime? originalFromDate;
  DateTime? originalToDate;
  TimeOfDay? originalStartTime;
  TimeOfDay? originalEndTime;

  // Updated Data
  String? updatedTitle;
  String? updatedDescription;
  String? updatedStatus;
  String? updatedStatusId;
  DateTime? updatedFromDate;
  DateTime? updatedToDate;
  TimeOfDay? updatedStartTime;
  TimeOfDay? updatedEndTime;

  // Flags to track if a field has been edited
  bool isTitleEdited = false;
  bool isDescriptionEdited = false;
  bool isStatusEdited = false;
  bool isFromDateEdited = false;
  bool isToDateEdited = false;
  bool isStartTimeEdited = false;
  bool isEndTimeEdited = false;

  bool _isLoading = false;

  // For uploading an image
  File? _selectedImage;

  final Map<String, String> _statusMap = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  // Controllers to manage text fields
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;

  @override
  void initState() {
    super.initState();
    _fetchMeetingDetails();

    // Initialize controllers
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
  }

  @override
  void dispose() {
    // Dispose controllers
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  //                   IMAGE PICK & UPLOAD LOGIC
  // ---------------------------------------------------------------
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final file = File(image.path);

        // Optional: Validate file size or type if needed
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
        final mimeType = lookupMimeType(image.path) ?? '';
        if (!mimeType.startsWith('image/')) {
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

        // Once image is picked, we upload it
        await _uploadImage();
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Image Picker Error',
        content: 'Failed to pick image: $e',
        isError: true,
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

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
      final uri = Uri.parse(
        '${widget.baseUrl}/api/work-tracking/meeting/insert-new-file/${widget.meetingId}',
      );

      final request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Prepare file to send in form-data
      final mimeType = lookupMimeType(_selectedImage!.path) ?? 'application/octet-stream';
      final mimeTypeData = mimeType.split('/');

      request.files.add(
        await http.MultipartFile.fromPath(
          'file_name', // The field name your backend expects
          _selectedImage!.path,
          contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar(
          message: 'Image uploaded successfully.',
          isError: false,
        );
      } else {
        String errorMessage = 'Failed to upload image.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showSnackBar(
          message: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        message: 'Error uploading image: $e',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // For reference, your existing color helper
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  Future<void> _fetchMeetingDetails() async {
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
        Uri.parse(
            '${widget.baseUrl}/api/work-tracking/meeting/get-all-meeting'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final meeting = (data['results'] as List).firstWhere(
              (item) => item['meeting_id'] == widget.meetingId,
          orElse: () => null,
        );
        if (meeting != null) {
          setState(() {
            originalTitle = meeting['title'] ?? '';
            originalDescription = meeting['description'] ?? '';
            originalStatus = meeting['s_name'] ?? 'Processing';
            originalStatusId = _statusMap[originalStatus] ??
                '0a8d93f0-1c05-42b2-8e56-984a578ef077';
            originalFromDate = meeting['from_date'] != null
                ? DateTime.parse(meeting['from_date'])
                : null;
            originalToDate = meeting['to_date'] != null
                ? DateTime.parse(meeting['to_date'])
                : null;
            originalStartTime = meeting['start_time'] != null &&
                meeting['start_time'] != ''
                ? TimeOfDay(
              hour: int.parse(meeting['start_time'].split(':')[0]),
              minute: int.parse(meeting['start_time'].split(':')[1]),
            )
                : null;
            originalEndTime = meeting['end_time'] != null &&
                meeting['end_time'] != ''
                ? TimeOfDay(
              hour: int.parse(meeting['end_time'].split(':')[0]),
              minute: int.parse(meeting['end_time'].split(':')[1]),
            )
                : null;

            // Initialize controllers with original data
            _titleController.text = originalTitle;
            _descriptionController.text = originalDescription;
            _startDateController.text = originalFromDate != null
                ? DateFormat('dd-MM-yyyy').format(originalFromDate!)
                : '';
            _endDateController.text = originalToDate != null
                ? DateFormat('dd-MM-yyyy').format(originalToDate!)
                : '';
            _startTimeController.text = originalStartTime != null
                ? originalStartTime!.format(context)
                : '';
            _endTimeController.text = originalEndTime != null
                ? originalEndTime!.format(context)
                : '';
          });
        } else {
          _showAlertDialog(
            title: 'Error',
            content: 'Meeting not found.',
            isError: true,
          );
        }
      } else {
        _showAlertDialog(
          title: 'Error',
          content: 'Failed to load meeting details.',
          isError: true,
        );
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        content: 'Error fetching meeting details: $e',
        isError: true,
      );
    }
    setState(() {
      _isLoading = false;
    });
  }
  Future<void> _selectStartDate() async {
    final DateTime initialDate = isFromDateEdited && updatedFromDate != null
        ? updatedFromDate!
        : originalFromDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        updatedFromDate = picked;
        isFromDateEdited = true;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay initialTime = isStartTimeEdited && updatedStartTime != null
        ? updatedStartTime!
        : originalStartTime ?? TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        updatedStartTime = picked;
        isStartTimeEdited = true;
        _startTimeController.text = picked.format(context);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime initialDate = isToDateEdited && updatedToDate != null
        ? updatedToDate!
        : originalToDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        updatedToDate = picked;
        isToDateEdited = true;
        _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay initialTime = isEndTimeEdited && updatedEndTime != null
        ? updatedEndTime!
        : originalEndTime ?? TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        updatedEndTime = picked;
        isEndTimeEdited = true;
        _endTimeController.text = picked.format(context);
      });
    }
  }

  Future<void> _updateMeeting() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    // Check if any field has been edited
    if (!isTitleEdited &&
        !isDescriptionEdited &&
        !isStatusEdited &&
        !isFromDateEdited &&
        !isToDateEdited &&
        !isStartTimeEdited &&
        !isEndTimeEdited) {
      _showSnackBar(
        message: 'No fields have been updated.',
        isError: false,
      );
      return;
    }

    // Combine date and time into single DateTime objects
    DateTime fromDateTime = originalFromDate ?? DateTime.now();
    if (isFromDateEdited && updatedFromDate != null) {
      fromDateTime = DateTime(
        updatedFromDate!.year,
        updatedFromDate!.month,
        updatedFromDate!.day,
        updatedStartTime?.hour ?? originalStartTime?.hour ?? 0,
        updatedStartTime?.minute ?? originalStartTime?.minute ?? 0,
      );
    } else if (isStartTimeEdited && updatedStartTime != null) {
      fromDateTime = DateTime(
        fromDateTime.year,
        fromDateTime.month,
        fromDateTime.day,
        updatedStartTime!.hour,
        updatedStartTime!.minute,
      );
    }

    DateTime toDateTime = originalToDate ?? DateTime.now();
    if (isToDateEdited && updatedToDate != null) {
      toDateTime = DateTime(
        updatedToDate!.year,
        updatedToDate!.month,
        updatedToDate!.day,
        updatedEndTime?.hour ?? originalEndTime?.hour ?? 0,
        updatedEndTime?.minute ?? originalEndTime?.minute ?? 0,
      );
    } else if (isEndTimeEdited && updatedEndTime != null) {
      toDateTime = DateTime(
        toDateTime.year,
        toDateTime.month,
        toDateTime.day,
        updatedEndTime!.hour,
        updatedEndTime!.minute,
      );
    }

    // Validate that end date is not before start date
    if (toDateTime.isBefore(fromDateTime)) {
      _showSnackBar(
        message: 'End date cannot be before start date.',
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
      // Prepare the request body with updated or original data
      Map<String, dynamic> body = {
        'title': isTitleEdited ? updatedTitle : originalTitle,
        'descriptions':
        isDescriptionEdited ? updatedDescription : originalDescription,
        'status_id': isStatusEdited ? updatedStatusId : originalStatusId,
        'fromdate': DateFormat('yyyy-MM-dd HH:mm:ss').format(fromDateTime),
        'todate': DateFormat('yyyy-MM-dd HH:mm:ss').format(toDateTime),
        'start_time': isStartTimeEdited && updatedStartTime != null
            ? _formatTime(updatedStartTime!)
            : originalStartTime != null
            ? _formatTime(originalStartTime!)
            : '',
        'end_time': isEndTimeEdited && updatedEndTime != null
            ? _formatTime(updatedEndTime!)
            : originalEndTime != null
            ? _formatTime(originalEndTime!)
            : '',
      };

      final response = await http.put(
        Uri.parse(
            '${widget.baseUrl}/api/work-tracking/meeting/update/${widget
                .meetingId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar(
          message: 'Meeting updated successfully.',
          isError: false,
        );
        // Optionally, refresh data or navigate back
      } else {
        String errorMessage = 'Failed to update meeting.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showSnackBar(
          message: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        message: 'Error updating meeting: $e',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
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

  // void _navigateToEditMembers() async {
  //   print('[_AddProcessingPageState] Navigating to SelectProcessingMembersPage with meetingId: ${widget.meetingId}');
  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => EditProcessingMembersPage(
  //         meetingId: widget.meetingId,
  //         baseUrl: widget.baseUrl,
  //         alreadySelectedMembers: selectedMembers,
  //       ),
  //     ),
  //   );
  //
  //   if (result != null && result is List<Map<String, dynamic>>) {
  //     setState(() {
  //       selectedMembers = result;
  //     });
  //     print('[_AddProcessingPageState] Members selected: ${selectedMembers.map((m) => m['employee_id']).toList()}');
  //   }
  // }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _deleteMeeting() async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Meeting'),
          content: const Text('Are you sure you want to delete this meeting?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors
                    .redAccent,
              ),
              child: const Text(
                  'Delete', style: TextStyle(color: Colors.white)),
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
      final response = await http.put(
        Uri.parse(
            '${widget.baseUrl}/api/work-tracking/meeting/delete/${widget
                .meetingId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar(
          message: 'Meeting deleted successfully.',
          isError: false,
        );
        Navigator.pop(context); // Navigate back after deletion
      } else {
        String errorMessage = 'Failed to delete meeting.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showSnackBar(
          message: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        message: 'Error deleting meeting: $e',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showAlertDialog({
    required String title,
    required String content,
    required bool isError,
  }) {
    showDialog(
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
                Navigator.of(context).pop();
                if (!isError &&
                    (title.toLowerCase().contains('success') ||
                        title.toLowerCase().contains('deleted'))) {
                  Navigator.of(context).pop(); // Navigate back on success
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditable,
    required Widget suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    VoidCallback? onTap,
    FormFieldValidator<String>? validator,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        absorbing: !isEditable,
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade600),
            border: const OutlineInputBorder(),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
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
          'Edit Processing',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
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
          padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18.0),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row of Delete and Update Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _deleteMeeting,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC2C2C2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  padding: const EdgeInsets.all(6.0),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _updateMeeting,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  padding: const EdgeInsets.all(6.0),
                                  child: const Icon(
                                    Icons.check,
                                    color: Color(0xFFDBB342),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Update',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

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
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Enter title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          updatedTitle = value;
                          isTitleEdited = true;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    // Row: Status Dropdown + Upload Image
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
                                value:
                                isStatusEdited ? updatedStatus : originalStatus,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.all(Radius.circular(8.0)),
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
                                    updatedStatus = newValue;
                                    updatedStatusId =
                                        _statusMap[updatedStatus!] ??
                                            '0a8d93f0-1c05-42b2-8e56-984a578ef077';
                                    isStatusEdited = true;
                                  });
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
                                  onPressed: _pickImage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 17.0,
                                      horizontal: (MediaQuery.of(context).size.width < 400) ? 40 : 53,
                                    ),
                                  ),
                                  child: Text(
                                    'Upload Image',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: (MediaQuery.of(context).size.width < 400) ? 12 : 14,
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

                    // Start Date & Time
                    Row(
                      children: [
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
                              GestureDetector(
                                onTap: _selectStartDate,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _startDateController,
                                    decoration: InputDecoration(
                                      hintText: 'yyyy-MM-dd',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
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
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Time',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: _selectStartTime,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _startTimeController,
                                    decoration: InputDecoration(
                                      hintText: 'HH:MM',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.access_time,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // End Date & Time
                    Row(
                      children: [
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
                              GestureDetector(
                                onTap: _selectEndDate,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _endDateController,
                                    decoration: InputDecoration(
                                      hintText: 'yyyy-MM-dd',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
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
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Time',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: _selectEndTime,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _endTimeController,
                                    decoration: InputDecoration(
                                      hintText: 'HH:MM',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.access_time,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // + Add People (Placeholder)
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     SizedBox(
                    //       width: constraints.maxWidth * 0.5,
                    //       child: ElevatedButton.icon(
                    //         onPressed: _isLoading
                    //             ? null
                    //             : _navigateToEditMembers,
                    //         icon: const Icon(Icons.person_add, color: Colors.black),
                    //         label: const Text(
                    //           'Add People',
                    //           style: TextStyle(color: Colors.black),
                    //         ),
                    //         style: ElevatedButton.styleFrom(
                    //           backgroundColor: Colors.green,
                    //           padding: const EdgeInsets.symmetric(
                    //             horizontal: 12.0,
                    //             vertical: 10.0,
                    //           ),
                    //           shape: RoundedRectangleBorder(
                    //             borderRadius: BorderRadius.circular(16.0),
                    //           ),
                    //           elevation: 3,
                    //         ),
                    //       ),
                    //     ),
                    //     // Selected Members Display
                    //     SizedBox(
                    //       width: constraints.maxWidth * 0.5 - 8,
                    //       child: _buildSelectedMembers(),
                    //     ),
                    //   ],
                    // ),
                    //
                    // const SizedBox(height: 18),

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
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Enter description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          updatedDescription = value;
                          isDescriptionEdited = true;
                        });
                      },
                    ),

                    const SizedBox(height: 30),
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
