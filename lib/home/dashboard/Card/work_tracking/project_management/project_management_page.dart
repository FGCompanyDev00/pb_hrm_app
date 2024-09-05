import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Finished'];
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  String _currentUserId = '';
  final WorkTrackingService _workTrackingService = WorkTrackingService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _fetchProjectData();
    _loadChatMessages();
    _loadCurrentUser();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent); // Jump to the bottom
      }
    });
  }

  Future<void> _loadChatMessages() async {
    try {
      final messages = await _workTrackingService.fetchChatMessages(widget.projectId);
      setState(() {
        _messages = messages.map((message) {
          return {
            ...message,
            'createBy_name': message['created_by'] == _currentUserId ? 'You' : message['createBy_name'],
          };
        }).toList();
      });
      _scrollToBottom(); // Ensure scrolling to the bottom after messages are loaded
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load chat messages: $e');
      }
    }
  }


  Widget _buildChatAndConversationTab(bool isDarkMode) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true, // Reverse the order of the list to show the latest message at the bottom
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final nextMessage = index + 1 < _messages.length ? _messages[index + 1] : null;

              // Check if the date of the current message is different from the next one (since list is reversed)
              final bool isNewDate = nextMessage == null ||
                  _formatDate(message['created_at']) != _formatDate(nextMessage['created_at']);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isNewDate) // Display date header
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          _formatDate(message['created_at']),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                    ),
                  _buildChatMessage(message, nextMessage, isDarkMode), // Message bubble
                ],
              );
            },
          ),
        ),
        _buildChatInput(isDarkMode), // Chat input at the bottom
      ],
    );
  }


  String _formatDate(String timestamp) {
    final DateTime messageDate = DateTime.parse(timestamp);
    final DateTime now = DateTime.now();

    if (messageDate.year == now.year && messageDate.month == now.month && messageDate.day == now.day) {
      return 'Today';
    } else if (messageDate.year == now.year && messageDate.month == now.month && messageDate.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd MMM yyyy').format(messageDate);
    }
  }

  String _formatTimestamp(String timestamp) {
    final DateTime messageTime = DateTime.parse(timestamp);
    return DateFormat('hh:mm a').format(messageTime); // Time in hh:mm AM/PM format
  }


  Widget _buildChatMessage(Map<String, dynamic> message, Map<String, dynamic>? nextMessage, bool isDarkMode) {
    final bool isSentByMe = message['created_by'] == _currentUserId;
    final String senderName = isSentByMe ? 'You' : message['createBy_name'] ?? 'Unknown'; // Replace current user name with 'You'

    final Color messageColor = isSentByMe
        ? Colors.blue.shade200 // Your own messages (light blue)
        : _assignChatBubbleColor(message['created_by']); // Different color for others

    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Alignment messageAlignment = isSentByMe ? Alignment.centerRight : Alignment.centerLeft;

    return GestureDetector(
      onTap: () {
        if (isSentByMe) {
          _showDeleteConfirmation(message['comment_id']); // Only allow deletion of own messages
        }
      },
      child: Align(
        alignment: messageAlignment,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: messageColor,
            borderRadius: BorderRadius.only(
              topLeft: isSentByMe ? const Radius.circular(12.0) : const Radius.circular(0),
              topRight: isSentByMe ? const Radius.circular(0) : const Radius.circular(12.0),
              bottomLeft: const Radius.circular(12.0),
              bottomRight: const Radius.circular(12.0),
            ),
          ),
          child: Column(
            crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isSentByMe) // Only show name for others' messages
                Text(
                  senderName,
                  style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 4),
              Text(
                message['comments'] ?? '',
                style: TextStyle(color: textColor, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(message['created_at']),
                style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _assignChatBubbleColor(String userId) {
    final List<Color> colors = [
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.red.shade100,
      Colors.yellow.shade100,
    ];

    final int hashValue = userId.hashCode % colors.length;
    return colors[hashValue];
  }

  Widget _buildChatInput(bool isDarkMode) {
    final Color backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color sendButtonColor = isDarkMode ? Colors.green[300]! : Colors.green;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: textColor),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 25,
              backgroundColor: sendButtonColor,
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
      ),
    );
  }

  String _currentUserName = '';

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      // Handle token missing case
      return;
    }

    final response = await http.get(
      Uri.parse('${widget.baseUrl}/api/display/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        setState(() {
          _currentUserId = data['results'][0]['id'];  // Set current user ID
          _currentUserName = data['results'][0]['employee_name']; // Set current user name
        });
      }
    }
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

  void _showDeleteConfirmation(String commentId) {
    print('Comment ID to delete: $commentId');  // For debugging

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Would you like to delete this message?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the modal
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the modal
                _deleteMessage(commentId); // Delete the message
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85.0),
        child: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          leading: Padding(
            padding: const EdgeInsets.only(top: 25.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          title: const Padding(
            padding: EdgeInsets.only(top: 34.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Spacer(flex: 2),
                Text(
                  'Work Tracking',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),


      body: Column(
        children: [

          TabBar(
            controller: _tabController,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.amber,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
            tabs: const [
              Tab(text: 'Assignment / Task'),
              Tab(text: 'Comment / Chat'),
            ],
          ),

          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProcessingOrDetailTab(filteredTasks),
                _buildChatAndConversationTab(isDarkMode),
              ],
            ),
          ),
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
                    gradient: isDarkMode
                        ? const LinearGradient(
                      colors: [Color(0xFF424242), Color(0xFF303030)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(1, 1),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(12.0),
                  ),

                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                      icon: const Icon(Icons.arrow_downward, color: Colors.amber),
                      iconSize: 28,
                      elevation: 16,
                      dropdownColor: isDarkMode ? const Color(0xFF424242) : Colors.white,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                              Icon(Icons.circle, color: _getStatusColor(value), size: 14),
                              const SizedBox(width: 10),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.greenAccent, Colors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10.0),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
                onPressed: () => _showTaskModal(),
              ),

            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchProjectData,
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
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
      'Finished': Colors.green,
    };

    final startDate = DateTime.parse(task['start_date'] ?? DateTime.now().toIso8601String());
    final dueDate = DateTime.parse(task['due_date'] ?? DateTime.now().toIso8601String());
    final daysRemaining = dueDate.difference(startDate).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE0E0F0),
            Color(0xFFF7F7FF),
            Color(0xFFFFFFFF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(4, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Row with Icon
            Row(
              children: [
                Icon(
                  Icons.circle,
                  color: progressColors[task['status']] ?? Colors.black,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  task['status'] ?? 'Unknown',
                  style: TextStyle(
                    color: progressColors[task['status']] ?? Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.more_vert,
                  color: Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title with Bold Style
            Text(
              task['title'] ?? 'No Title',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Start Date and End Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIconTextRow(
                  icon: Icons.calendar_today,
                  label: 'Start Date: ${task['start_date'] ?? 'N/A'}',
                  iconColor: Colors.orangeAccent,
                ),
                const SizedBox(height: 8),
                _buildIconTextRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Due Date: ${task['due_date'] ?? 'N/A'}',
                  iconColor: Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Days Remaining
            _buildIconTextRow(
              icon: Icons.timelapse,
              label: 'Days Remaining: $daysRemaining',
              iconColor: Colors.greenAccent,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              task['description'] ?? 'No Description',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper Widget for Icon + Text Row
  Widget _buildIconTextRow({required IconData icon, required String label, Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? Colors.black54, size: 18), // Icon with color
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
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

  Future<void> _deleteMessage(String commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      return;
    }

    final url = Uri.parse('${widget.baseUrl}/api/work-tracking/project-comments/delete/$commentId');

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        // Remove the message from the list of messages
        _messages.removeWhere((message) => message['comment_id'] == commentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted successfully')),
      );
    } else {
      // Capture error message from the response
      final responseData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: ${responseData['error'] ?? 'Unknown error'}')),
      );
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await _workTrackingService.deleteAssignment(taskId);
      _fetchProjectData();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to delete task: $e');
      }
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
      if (kDebugMode) {
        print('Failed to add task: $e');
      }
    }
  }

  Future<void> _addMembersToAssignment(String asId, List<Map<String, dynamic>> members) async {
    try {
      await _workTrackingService.addMembersToAssignment(asId, members);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to add members to assignment: $e');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Finishedr':
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

class CustomAppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0.0, size.height - 30);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 30);
    path.lineTo(size.width, 0.0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
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
      if (kDebugMode) {
        print('Failed to load assignment members: $e');
      }
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

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() {
        _files.add(File(result.files.single.path!));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No file selected')));
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

    Provider.of<ThemeNotifier>(context);

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
// Display the uploaded file names
              Wrap(
                spacing: 8.0,
                children: _files.map((file) {
                  return Chip(
                    label: Text(file.path.split('/').last), // Display only the file name
                    onDeleted: () {
                      setState(() {
                        _files.remove(file);
                      });
                    },
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
      case 'Finished':
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
      if (kDebugMode) {
        print('Error fetching members: $e');
      }
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