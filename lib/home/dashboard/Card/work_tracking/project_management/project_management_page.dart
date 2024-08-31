import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/services/image_viewer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class ProjectManagementPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const ProjectManagementPage({super.key, required this.projectId, required this.baseUrl});

  @override
  _ProjectManagementPageState createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _messages = [];
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Completed'];
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  String _shortenedProjectId = '';
  String _currentUserId = '';
  final WorkTrackingService _workTrackingService = WorkTrackingService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _shortenedProjectId = '${widget.projectId.substring(0, 8)}...';
    _loadUserData();
    _fetchProjectData();
    _loadChatMessages();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId') ?? '';
    });
  }

  Future<void> _fetchProjectData() async {
    try {
      final tasks = await _workTrackingService.fetchAssignments(widget.projectId);
      setState(() {
        _tasks = tasks.where((task) => task['proj_id'] == widget.projectId).map((task) {
          return {
            'id': task['id'],
            'title': task['title'] ?? 'No Title',
            'status': task['s_name'] ?? 'Unknown',
            'start_date': task['created_at']?.substring(0, 10) ?? 'N/A',
            'due_date': task['updated_at']?.substring(0, 10) ?? 'N/A',
            'description': task['description'] ?? 'No Description',
            'files': task['file_name'] != null ? task['file_name'].split(',') : [],
          };
        }).toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load project data: $e');
      }
    }
  }

  Future<void> _loadChatMessages() async {
    try {
      final messages = await _workTrackingService.fetchChatMessages(widget.projectId);
      setState(() {
        _messages = messages.reversed.map((message) {
          return {
            ...message,
            'createBy_name': message['created_by'] == _currentUserId ? 'You' : message['createBy_name']
          };
        }).toList(); // Reverse messages for newest at bottom
      });
      _scrollToBottom();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load chat messages: $e');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Widget _buildChatInput(bool isDarkMode) {
    final Color backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message',
                filled: true,
                fillColor: backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.yellow, width: 2),
                ),
                hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
              ),
              style: TextStyle(color: textColor),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.green,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {
                if (_messageController.text.isNotEmpty) {
                  _sendMessage(_messageController.text);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> message, bool isDarkMode) {
    final bool isSentByMe = message['created_by'] == _currentUserId;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color backgroundColor = isSentByMe ? Colors.green.shade100 : Colors.blue.shade100;
    final DateTime messageTime = DateTime.parse(message['created_at'] ?? DateTime.now().toIso8601String());

    String formattedTime = DateFormat('hh:mm a').format(messageTime);
    String formattedDate;

    if (messageTime.day == DateTime.now().day) {
      formattedDate = 'Today';
    } else {
      formattedDate = DateFormat('dd MMM yyyy').format(messageTime);
    }

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['createBy_name'] ?? 'Unknown',
              style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              message['comments'] ?? '',
              style: TextStyle(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '$formattedDate, $formattedTime',
              style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAndConversationTab(bool isDarkMode) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildChatMessage(_messages[index], isDarkMode);
                },
              ),
            ),
            _buildChatInput(isDarkMode),
          ],
        ),
      ],
    );
  }

  Future<void> _sendMessage(String message) async {
    try {
      await _workTrackingService.sendChatMessage(widget.projectId, message);
      _addMessage(message);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send message: $e');
      }
    }
  }

  void _addMessage(String message) {
    final DateTime now = DateTime.now();
    setState(() {
      _messages.insert(0, {
        'comments': message,
        'created_at': now.toIso8601String(),
        'createBy_name': 'You',
        'created_by': _currentUserId,
      });
    });
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    List<Map<String, dynamic>> filteredTasks = _tasks.where((task) => _selectedStatus == 'All Status' || task['status'] == _selectedStatus).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Image.asset(
          'assets/background.png',
          fit: BoxFit.cover,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Center(
              child: Text(
                'Work Tracking',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Project ID'),
                      content: Text(widget.projectId),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Text(
                _shortenedProjectId,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: 'Processing or Detail'),
            Tab(text: 'Chat and Conversation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProcessingOrDetailTab(filteredTasks),
          _buildChatAndConversationTab(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildProcessingOrDetailTab(List<Map<String, dynamic>> filteredTasks) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButton<String>(
                    value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                    icon: const Icon(Icons.arrow_downward),
                    iconSize: 24,
                    elevation: 16,
                    style: const TextStyle(color: Colors.black),
                    underline: Container(
                      height: 2,
                      color: Colors.transparent,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedStatus = newValue!;
                      });
                    },
                    items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: _getStatusColor(value), size: 12),
                            const SizedBox(width: 8),
                            Text(value),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.green),
                onPressed: () => _showTaskModal(),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchProjectData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: filteredTasks.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _showTaskViewModal(filteredTasks[index], index);
                  },
                  child: _buildTaskCard(filteredTasks[index], index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, int index) {
    final progressColors = {
      'Pending': Colors.orange,
      'Processing': Colors.blue,
      'Completed': Colors.green,
    };

    final startDate = DateTime.parse(task['start_date'] ?? DateTime.now().toIso8601String());
    final dueDate = DateTime.parse(task['due_date'] ?? DateTime.now().toIso8601String());
    final days = dueDate.difference(startDate).inDays;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: progressColors[task['status']] ?? Colors.black),
      ),
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  task['status'] ?? 'Unknown',
                  style: TextStyle(color: progressColors[task['status']] ?? Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Title: ${task['title'] ?? 'No Title'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Start Date: ${task['start_date'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'Due Date: ${task['due_date'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'Days: $days',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'Description: ${task['description'] ?? 'No Description'}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskViewModal(Map<String, dynamic> task, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('View Task'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title: ${task['title'] ?? 'No Title'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('Status: ${task['status'] ?? 'Unknown'}', style: TextStyle(color: _getStatusColor(task['status'] ?? 'Unknown'))),
                const SizedBox(height: 10),
                Text('Start Date: ${task['start_date'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Text('Due Date: ${task['due_date'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Text('Description: ${task['description'] ?? 'No Description'}', style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 10),
                const Text('Attachments:'),
                const SizedBox(height: 10),
                Column(
                  children: [
                    ...task['files'].map<Widget>((filePath) {
                      final fileExtension = filePath.split('.').last.toLowerCase(); // Define the fileExtension here
                      return GestureDetector(
                        onTap: () {
                          if (fileExtension == 'pdf') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PdfViewer(filePath: '${widget.baseUrl}/$filePath'),
                              ),
                            );
                          } else if (['jpg', 'jpeg', 'png'].contains(fileExtension)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageViewer(imagePath: '${widget.baseUrl}/$filePath'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Unsupported file format')),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(fileExtension == 'pdf' ? Icons.picture_as_pdf : Icons.image),
                              const SizedBox(width: 8),
                              Text(filePath.split('/').last),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteTask(task['id']);
                Navigator.pop(context);  // Close the modal after deleting
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showTaskModal(task: task, index: index, isEdit: true);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.amber,
              ),
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await _workTrackingService.deleteAssignment(taskId);
      _fetchProjectData();
    } catch (e) {
      print('Failed to delete task: $e');
    }
  }

  void _showTaskModal({Map<String, dynamic>? task, int? index, bool isEdit = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _TaskModal(
          task: task,
          onSave: (newTask) {
            if (task != null && index != null) {
              _editTask(index, newTask);
            } else {
              _addTask(newTask);
            }
          },
          isEdit: isEdit,
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        );
      },
    );
  }

  void _editTask(int index, Map<String, dynamic> updatedTask) {
    setState(() {
      _tasks[index] = updatedTask;
    });
  }

  Future<void> _addTask(Map<String, dynamic> task) async {
    try {
      final asId = await _workTrackingService.addAssignment(widget.projectId, task);
      if (asId != null) {
        await _addMembersToAssignment(asId, task['members']);
      }
      _fetchProjectData();
    } catch (e) {
      print('Failed to add task: $e');
    }
  }

  Future<void> _addMembersToAssignment(String asId, List<Map<String, dynamic>> members) async {
    try {
      await _workTrackingService.addMembersToAssignment(asId, members);
    } catch (e) {
      print('Failed to add members to assignment: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}

class _TaskModal extends StatefulWidget {
  final Map<String, dynamic>? task;
  final Function(Map<String, dynamic>) onSave;
  final bool isEdit;
  final String projectId;
  final String baseUrl;

  static const List<Map<String, dynamic>> statusOptions = [
    {'id': '40d2ba5e-a978-47ce-bc48-caceca8668e9', 'name': 'Pending'},
    {'id': '0a8d93f0-1c05-42b2-8e56-984a578ef077', 'name': 'Processing'},
    {'id': 'e35569eb-75e1-4005-9232-bfb57303b8b3', 'name': 'Completed'},
  ];

  const _TaskModal({
    this.task,
    required this.onSave,
    this.isEdit = false,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  __TaskModalState createState() => __TaskModalState();
}

class __TaskModalState extends State<_TaskModal> {
  late TextEditingController _titleController;
  late TextEditingController _startDateController;
  late TextEditingController _dueDateController;
  late TextEditingController _descriptionController;
  String _selectedStatus = 'Pending';
  final ImagePicker _picker = ImagePicker();
  final List<File> _files = [];
  List<Map<String, dynamic>> _selectedPeople = [];
  final _formKey = GlobalKey<FormState>();

  final WorkTrackingService _workTrackingService = WorkTrackingService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?['title'] ?? '');
    _startDateController = TextEditingController(text: widget.task?['start_date'] ?? '');
    _dueDateController = TextEditingController(text: widget.task?['due_date'] ?? '');
    _descriptionController = TextEditingController(text: widget.task?['description'] ?? '');
    _selectedStatus = widget.task?['status'] ?? _TaskModal.statusOptions.first['id'];

    if (widget.isEdit) {
      _fetchAssignmentMembers(); // Ensure members are fetched only for editing.
    }
  }

  Future<void> _fetchAssignmentMembers() async {
    try {
      final members = await _workTrackingService.fetchAssignmentMembers(widget.projectId);
      setState(() {
        _selectedPeople = members;
      });
    } catch (e) {
      print('Failed to load assignment members: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startDateController.dispose();
    _dueDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked.isAfter(DateTime.parse(_startDateController.text))) {
      setState(() {
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due date must be after start date')),
      );
    }
  }

  Future<void> _pickFile() async {
    if (_files.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only upload up to 2 files')));
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _files.add(File(pickedFile.path));
      });
    }
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token is null. Please log in again.')),
        );
        return;
      }

      // Remove duplicate members
      final uniqueMembers = _selectedPeople.toSet().toList();

      final task = {
        'title': _titleController.text,
        'start_date': _startDateController.text,
        'due_date': _dueDateController.text,
        'description': _descriptionController.text,
        'status_id': _selectedStatus,
        'members': uniqueMembers.map((member) => {'employee_id': member['employee_id']}).toList(),
      };

      try {
        if (widget.isEdit && widget.task != null) {
          await _workTrackingService.updateAssignment(
            widget.task!['id'].toString(),
            task,
          );
        } else {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('${widget.baseUrl}/api/work-tracking/ass/insert'),
          );

          request.headers['Authorization'] = 'Bearer $token';
          request.fields['project_id'] = widget.projectId;
          request.fields['status_id'] = _selectedStatus;
          request.fields['title'] = _titleController.text;
          request.fields['descriptions'] = _descriptionController.text;
          request.fields['start_date'] = _startDateController.text;
          request.fields['due_date'] = _dueDateController.text;
          request.fields['memberDetails'] = jsonEncode(task['members']);

          for (var file in _files) {
            request.files.add(await http.MultipartFile.fromPath('file_name', file.path));
          }

          final response = await request.send();

          if (response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Assignment added successfully')),
            );
            Navigator.pop(context, true);
          } else {
            final errorResponse = await response.stream.bytesToString();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add assignment: $errorResponse')),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add assignment: $e')),
        );
      }
    }
  }


  void _openAddPeoplePage() async {
    final selectedPeople = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPeoplePageWorkTracking(
          asId: widget.projectId,
          onSelectedPeople: (people) {
            setState(() {
              _selectedPeople = people;
            });
          },
        ),
      ),
    );

    if (selectedPeople != null) {
      setState(() {
        _selectedPeople = selectedPeople;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(widget.task != null ? 'Edit Task' : 'Add Task'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _TaskModal.statusOptions.any((status) => status['id'] == _selectedStatus) ? _selectedStatus : null,
                decoration: const InputDecoration(labelText: 'Status'),
                icon: const Icon(Icons.arrow_downward),
                iconSize: 24,
                elevation: 16,
                style: const TextStyle(color: Colors.black),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedStatus = newValue!;
                  });
                },
                items: _TaskModal.statusOptions
                    .map<DropdownMenuItem<String>>((status) {
                  return DropdownMenuItem<String>(
                    value: status['id'],
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: _getStatusColor(status['name']), size: 12),
                        const SizedBox(width: 8),
                        Text(status['name']),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _selectStartDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _startDateController,
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a start date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _selectDueDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dueDateController,
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an end date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: const Text('Upload File'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: _files.map((file) {
                  return Stack(
                    children: [
                      Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _files.remove(file);
                            });
                          },
                          child: const Icon(Icons.remove_circle, color: Colors.red),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _openAddPeoplePage,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Members'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: _selectedPeople.map((person) {
                  return Chip(
                    label: Text(person['name'] ?? 'No Name'),
                    onDeleted: () {
                      setState(() {
                        _selectedPeople.remove(person);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveTask,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.amber,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Color _getStatusColor(String statusName) {
    switch (statusName) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}

class AddPeoplePageWorkTracking extends StatefulWidget {
  final String asId;
  final Function(List<Map<String, dynamic>>) onSelectedPeople;

  const AddPeoplePageWorkTracking({super.key, required this.asId, required this.onSelectedPeople});

  @override
  _AddPeoplePageWorkTrackingState createState() => _AddPeoplePageWorkTrackingState();
}

class _AddPeoplePageWorkTrackingState extends State<AddPeoplePageWorkTracking> {
  List<Map<String, dynamic>> _members = [];
  final List<Map<String, dynamic>> _selectedPeople = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final members = await WorkTrackingService().fetchAssignmentMembers(widget.asId);
      setState(() {
        _members = members.map((member) {
          return {
            'name': member['name'] ?? 'Unknown Name',
            'surname': member['surname'] ?? '',
            'email': member['email'] ?? 'Unknown Email',
            'image': member['image'] ?? '',
            'isSelected': member['isSelected'] ?? false,
            'employee_id': member['employee_id'] ?? '',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching members: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      final selectedMember = _members[index];
      final isAlreadySelected = _selectedPeople.any((member) => member['employee_id'] == selectedMember['employee_id']);

      if (!isAlreadySelected) {
        selectedMember['isSelected'] = true;
        _selectedPeople.add(selectedMember);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selectedMember['name']} is already selected')),
        );
      }
    });
  }


  void _confirmSelection() {
    widget.onSelectedPeople(_selectedPeople);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _members.where((member) {
      final memberName = member['name'] ?? '';
      return memberName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add People'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(filteredMembers[index]['image'] ?? ''),
                      child: filteredMembers[index]['image'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(filteredMembers[index]['name'] ?? 'No Name'),
                    subtitle: Text('${filteredMembers[index]['surname'] ?? ''} - ${filteredMembers[index]['email'] ?? ''}'),
                    trailing: Checkbox(
                      value: filteredMembers[index]['isSelected'] ?? false,
                      onChanged: (bool? value) {
                        _toggleSelection(index);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}

class PdfViewer extends StatelessWidget {
  final String filePath;

  const PdfViewer({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
      ),
      body: PDFView(
        filePath: filePath,
      ),
    );
  }
}