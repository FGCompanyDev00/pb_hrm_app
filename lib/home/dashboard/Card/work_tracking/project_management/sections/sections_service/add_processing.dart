import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_processing_members.dart';

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
  String _title = '';
  String _description = '';
  String _selectedStatus = 'Processing';
  String _statusId = '0a8d93f0-1c05-42b2-8e56-984a578ef077';
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  List<File> _selectedImages = [];
  List<Map<String, dynamic>> _selectedMembers = [];
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

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final List<XFile>? images = await picker.pickMultiImage();
      if (images != null && images.isNotEmpty) {
        for (var image in images) {
          var compressedImage = await FlutterImageCompress.compressAndGetFile(
            image.path,
            image.path + '_compressed.jpg',
            quality: 50,
          );
          if (compressedImage != null) {
            setState(() {
              _selectedImages.add(compressedImage as File);
            });
          }
        }
      }
    } catch (e) {
      _showErrorDialog('Error picking images: $e');
    }
  }

  Future<void> _navigateToAddMembers() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectProcessingMembersPage(
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        ),
      ),
    );
    if (selected != null && selected is List<Map<String, dynamic>>) {
      await _fetchMembersImages(selected);
    } else {
      _showErrorDialog('Failed to select members correctly.');
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
          final Map<String, dynamic> data =
              jsonDecode(response.body)['results'] ?? {};
          membersWithImages.add({
            'employee_id': member['employee_id'],
            'employee_name': member['name'],
            'employee_surname': member['surname'],
            'images': data['images'] ?? '',
          });
        } else {
          membersWithImages.add({
            'employee_id': member['employee_id'],
            'employee_name': member['name'],
            'employee_surname': member['surname'],
            'images': '',
          });
        }
      } catch (e) {
        membersWithImages.add({
          'employee_id': member['employee_id'],
          'employee_name': member['name'],
          'employee_surname': member['surname'],
          'images': '',
        });
      }
    }

    setState(() {
      _selectedMembers = membersWithImages;
    });
  }

  Future<void> _addProcessing() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Please correct the errors in the form.');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showErrorDialog('Please select both start and end dates.');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showErrorDialog('End date cannot be before start date.');
      return;
    }

    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showErrorDialog('Token is null. Please log in again.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final fromDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final toDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);

      String startTimeStr = _startTime != null
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : '';
      String endTimeStr = _endTime != null
          ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
          : '';

      List<Map<String, dynamic>> membersDetails = _selectedMembers
          .map((member) => {"employee_id": member['employee_id']})
          .toList();
      String membersDetailsStr = jsonEncode(membersDetails);

      var uri = Uri.parse('${widget.baseUrl}/api/work-tracking/meeting/insert');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['project_id'] = widget.projectId;
      request.fields['title'] = _title;
      request.fields['descriptions'] = _description;
      request.fields['status_id'] = _statusId;
      request.fields['fromdate'] = fromDateStr;
      request.fields['todate'] = toDateStr;
      request.fields['start_time'] = startTimeStr;
      request.fields['end_time'] = endTimeStr;
      request.fields['membersDetails'] = membersDetailsStr;

      if (_selectedImages.isNotEmpty) {
        for (var image in _selectedImages) {
          var stream = http.ByteStream(image.openRead());
          var length = await image.length();
          var multipartFile = http.MultipartFile(
            'file_name',
            stream,
            length,
            filename: image.path.split('/').last,
          );
          request.files.add(multipartFile);
        }
      }

      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Processing item added successfully.');
        Navigator.pop(context, true);
      } else {
        String errorMessage = 'Failed to add processing item.';
        try {
          final contentType = response.headers['content-type'];
          if (contentType != null && contentType.contains('application/json')) {
            final responseBody = await response.stream.bytesToString();
            final responseData = jsonDecode(responseBody);
            errorMessage = responseData['message'] ?? errorMessage;
          } else {
            errorMessage = 'Server error: ${response.statusCode}';
          }
        } catch (e) {}
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      _showErrorDialog('Error adding processing item: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

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
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

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
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectedImages() {
    if (_selectedImages.isEmpty) return Container();
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _selectedImages.map((image) {
        return Stack(
          children: [
            Image.file(
              image,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImages.remove(image);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSelectedMembers() {
    if (_selectedMembers.isEmpty) return Container();
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _selectedMembers.map((member) {
        return Stack(
          children: [
            CircleAvatar(
              backgroundImage: member['images'] != null && member['images'] != ''
                  ? NetworkImage(member['images'])
                  : const AssetImage('assets/default_avatar.png') as ImageProvider,
              radius: 20,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMembers.remove(member);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
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
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addProcessing,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
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
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.upload, color: Colors.white),
                      label: const Text(
                        'Upload Images',
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
                const SizedBox(height: 16),
                _buildSelectedImages(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectStartDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _selectStartDate,
                              ),
                            ),
                            validator: (value) {
                              if (_startDate == null) {
                                return 'Please select start date';
                              }
                              return null;
                            },
                            controller: TextEditingController(
                              text: _startDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                  .format(_startDate!)
                                  : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectStartTime,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Start Time',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: _selectStartTime,
                              ),
                            ),
                            controller: TextEditingController(
                              text: _startTime != null
                                  ? _startTime!.format(context)
                                  : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectEndDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _selectEndDate,
                              ),
                            ),
                            validator: (value) {
                              if (_endDate == null) {
                                return 'Please select end date';
                              }
                              if (_startDate != null &&
                                  _endDate!.isBefore(_startDate!)) {
                                return 'End date cannot be before start date';
                              }
                              return null;
                            },
                            controller: TextEditingController(
                              text: _endDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                  .format(_endDate!)
                                  : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectEndTime,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'End Time',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: _selectEndTime,
                              ),
                            ),
                            controller: TextEditingController(
                              text: _endTime != null
                                  ? _endTime!.format(context)
                                  : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _navigateToAddMembers,
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text(
                        'Add People',
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSelectedMembers(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
