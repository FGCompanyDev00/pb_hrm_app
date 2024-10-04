import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class UpdateProcessingPage extends StatefulWidget {
  final String meetingId;
  final String projectId;
  final String baseUrl;

  const UpdateProcessingPage({
    Key? key,
    required this.meetingId,
    required this.projectId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  _UpdateProcessingPageState createState() => _UpdateProcessingPageState();
}

class _UpdateProcessingPageState extends State<UpdateProcessingPage> {
  final _formKey = GlobalKey<FormState>();

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

  final Map<String, String> _statusMap = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  @override
  void initState() {
    super.initState();
    _fetchMeetingDetails();
  }

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
        Uri.parse('${widget.baseUrl}/api/work-tracking/meeting/get-all-meeting'),
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
            originalDescription = meeting['descriptions'] ?? '';
            originalStatus = meeting['s_name'] ?? 'Processing';
            originalStatusId = _statusMap[originalStatus] ??
                '0a8d93f0-1c05-42b2-8e56-984a578ef077';
            originalFromDate = meeting['fromdate'] != null
                ? DateTime.parse(meeting['fromdate'])
                : null;
            originalToDate = meeting['todate'] != null
                ? DateTime.parse(meeting['todate'])
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
      });
    }
  }

  Future<void> _updateMeeting() async {
    // Check if any field has been edited
    if (!isTitleEdited &&
        !isDescriptionEdited &&
        !isStatusEdited &&
        !isFromDateEdited &&
        !isToDateEdited &&
        !isStartTimeEdited &&
        !isEndTimeEdited) {
      _showAlertDialog(
        title: 'No Changes',
        content: 'No fields have been updated.',
        isError: false,
      );
      return;
    }

    // Combine date and time into single DateTime strings
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
      _showAlertDialog(
        title: 'Invalid Dates',
        content: 'End date cannot be before start date.',
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
            ? '${_formatTime(updatedStartTime!)}'
            : originalStartTime != null
            ? '${_formatTime(originalStartTime!)}'
            : '',
        'end_time': isEndTimeEdited && updatedEndTime != null
            ? '${_formatTime(updatedEndTime!)}'
            : originalEndTime != null
            ? '${_formatTime(originalEndTime!)}'
            : '',
      };

      final response = await http.put(
        Uri.parse(
            '${widget.baseUrl}/api/work-tracking/meeting/update/${widget.meetingId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showAlertDialog(
          title: 'Success',
          content: 'Meeting updated successfully.',
          isError: false,
        );
      } else {
        String errorMessage = 'Failed to update meeting.';
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
        content: 'Error updating meeting: $e',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

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
            '${widget.baseUrl}/api/work-tracking/meeting/delete/${widget.meetingId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showAlertDialog(
          title: 'Success',
          content: 'Meeting deleted successfully.',
          isError: false,
        );
      } else {
        String errorMessage = 'Failed to delete meeting.';
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
        content: 'Error deleting meeting: $e',
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

                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditableField({
    required String label,
    required bool isEdited,
    required String initialValue,
    required Function(String) onChanged,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isEdited ? 1.0 : 0.5,
        child: TextFormField(
          initialValue: isEdited ? initialValue : originalTitle,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            // Optional fields, no validation required
            return null;
          },
          onChanged: (value) {
            onChanged(value);
          },
        ),
      ),
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
          'Edit Processing Item',
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
                // Delete and Update Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _deleteMeeting,
                        icon:
                        const Icon(Icons.close, color: Colors.white),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey, // Grey button
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
                        onPressed: _updateMeeting,
                        icon:
                        const Icon(Icons.check, color: Colors.black),
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
                GestureDetector(
                  onTap: () {
                    if (!isTitleEdited) {
                      setState(() {
                        isTitleEdited = true;
                        updatedTitle = originalTitle;
                      });
                    }
                  },
                  child: Opacity(
                    opacity: isTitleEdited ? 1.0 : 0.5,
                    child: TextFormField(
                      initialValue:
                      isTitleEdited ? updatedTitle : originalTitle,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        // Optional field
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          updatedTitle = value;
                          isTitleEdited = true;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Status Dropdown
                GestureDetector(
                  onTap: () {
                    if (!isStatusEdited) {
                      setState(() {
                        isStatusEdited = true;
                        updatedStatus = originalStatus;
                        updatedStatusId = originalStatusId;
                      });
                    }
                  },
                  child: Opacity(
                    opacity: isStatusEdited ? 1.0 : 0.5,
                    child: DropdownButtonFormField<String>(
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
                      items: ['Processing', 'Pending', 'Finished']
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
                      onChanged: isStatusEdited
                          ? (String? newValue) {
                        setState(() {
                          updatedStatus = newValue!;
                          updatedStatusId =
                          _statusMap[updatedStatus!]!;
                        });
                      }
                          : null,
                      validator: (value) {
                        // Optional field
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Start Date-Time
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!isFromDateEdited) {
                            setState(() {
                              isFromDateEdited = true;
                              updatedFromDate = originalFromDate;
                              updatedStartTime = originalStartTime;
                            });
                          }
                          _selectStartDate();
                        },
                        child: Opacity(
                          opacity: isFromDateEdited ? 1.0 : 0.5,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () {
                                    if (!isFromDateEdited) {
                                      setState(() {
                                        isFromDateEdited = true;
                                        updatedFromDate =
                                            originalFromDate;
                                        updatedStartTime =
                                            originalStartTime;
                                      });
                                    }
                                    _selectStartDate();
                                  },
                                ),
                              ),
                              validator: (value) {
                                // Optional field
                                return null;
                              },
                              controller: TextEditingController(
                                text: isFromDateEdited &&
                                    updatedFromDate != null
                                    ? DateFormat('yyyy-MM-dd')
                                    .format(updatedFromDate!)
                                    : originalFromDate != null
                                    ? DateFormat('yyyy-MM-dd')
                                    .format(originalFromDate!)
                                    : '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!isStartTimeEdited) {
                            setState(() {
                              isStartTimeEdited = true;
                              updatedStartTime = originalStartTime;
                            });
                          }
                          _selectStartTime();
                        },
                        child: Opacity(
                          opacity: isStartTimeEdited ? 1.0 : 0.5,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Start Time',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time),
                                  onPressed: () {
                                    if (!isStartTimeEdited) {
                                      setState(() {
                                        isStartTimeEdited = true;
                                        updatedStartTime =
                                            originalStartTime;
                                      });
                                    }
                                    _selectStartTime();
                                  },
                                ),
                              ),
                              validator: (value) {
                                // Optional field
                                return null;
                              },
                              controller: TextEditingController(
                                text: isStartTimeEdited &&
                                    updatedStartTime != null
                                    ? updatedStartTime!.format(context)
                                    : originalStartTime != null
                                    ? originalStartTime!.format(context)
                                    : '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // End Date-Time
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!isToDateEdited) {
                            setState(() {
                              isToDateEdited = true;
                              updatedToDate = originalToDate;
                              updatedEndTime = originalEndTime;
                            });
                          }
                          _selectEndDate();
                        },
                        child: Opacity(
                          opacity: isToDateEdited ? 1.0 : 0.5,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () {
                                    if (!isToDateEdited) {
                                      setState(() {
                                        isToDateEdited = true;
                                        updatedToDate = originalToDate;
                                        updatedEndTime = originalEndTime;
                                      });
                                    }
                                    _selectEndDate();
                                  },
                                ),
                              ),
                              validator: (value) {
                                // Optional field
                                return null;
                              },
                              controller: TextEditingController(
                                text: isToDateEdited && updatedToDate != null
                                    ? DateFormat('yyyy-MM-dd')
                                    .format(updatedToDate!)
                                    : originalToDate != null
                                    ? DateFormat('yyyy-MM-dd')
                                    .format(originalToDate!)
                                    : '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!isEndTimeEdited) {
                            setState(() {
                              isEndTimeEdited = true;
                              updatedEndTime = originalEndTime;
                            });
                          }
                          _selectEndTime();
                        },
                        child: Opacity(
                          opacity: isEndTimeEdited ? 1.0 : 0.5,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'End Time',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time),
                                  onPressed: () {
                                    if (!isEndTimeEdited) {
                                      setState(() {
                                        isEndTimeEdited = true;
                                        updatedEndTime = originalEndTime;
                                      });
                                    }
                                    _selectEndTime();
                                  },
                                ),
                              ),
                              validator: (value) {
                                // Optional field
                                return null;
                              },
                              controller: TextEditingController(
                                text: isEndTimeEdited && updatedEndTime != null
                                    ? updatedEndTime!.format(context)
                                    : originalEndTime != null
                                    ? originalEndTime!.format(context)
                                    : '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Description Input
                GestureDetector(
                  onTap: () {
                    if (!isDescriptionEdited) {
                      setState(() {
                        isDescriptionEdited = true;
                        updatedDescription = originalDescription;
                      });
                    }
                  },
                  child: Opacity(
                    opacity: isDescriptionEdited ? 1.0 : 0.5,
                    child: TextFormField(
                      initialValue: isDescriptionEdited
                          ? updatedDescription
                          : originalDescription,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        // Optional field
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          updatedDescription = value;
                          isDescriptionEdited = true;
                        });
                      },
                    ),
                  ),
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
