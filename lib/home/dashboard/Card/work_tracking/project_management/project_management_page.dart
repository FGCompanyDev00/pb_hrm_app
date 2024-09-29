import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/addpeoplepageworktracking.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/appbarclipper.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/backup_project_management_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/pdfviewer.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/taskmodal.dart';
import 'package:pb_hrsystem/services/assignment_service.dart';
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

class _ProjectManagementPageState extends State<ProjectManagementPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _messages = [];
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Finished'];
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  String _currentUserId = '';
  final WorkTrackingService _workTrackingService = WorkTrackingService();
  final AssignmentService _assignmentService = AssignmentService();
  final ScrollController _scrollController = ScrollController();

  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Tab controller with 3 tabs now
    _loadUserData();
    _fetchProjectData();
    _loadChatMessages();
    _loadCurrentUser();
  }

  // Method to delete a member from a task
  Future<void> _deleteMember(String memberId, int taskIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      return;
    }

    final url = Uri.parse('${widget.baseUrl}/api/work-tracking/assignment-members/delete/$memberId');

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _tasks[taskIndex]['members'].removeWhere((member) => member['id'] == memberId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member deleted successfully')),
      );
    } else {
      final responseData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete member: ${responseData['error'] ?? 'Unknown error'}')),
      );
    }
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
            'as_id': task['as_id'], 
            'title': task['title'] ?? 'No Title',
            'status': task['s_name'] ?? 'Unknown',
            'start_date': task['created_at']?.substring(0, 10) ?? 'N/A',
            'due_date': task['updated_at']?.substring(0, 10) ?? 'N/A',
            'description': task['description'] ?? 'No Description',
            'files': task['file_name'] != null ? task['file_name'].split(',') : [],
            'members': task['members'] ?? [],
          };
        }).toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load project data: $e');
      }
    }
  }

  void _showAddTaskModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TaskModal(
          onSave: (newTask) async {
            _addTask(newTask);
          },
          isEdit: false,
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        );
      },
    ).then((value) {
      if (value == true) {
        _refreshWholePage(); // Full page refresh
      }
    });
  }

  void _refreshWholePage() {
    setState(() {
      _fetchProjectData();
      _tabController = TabController(length: 3, vsync: this); // Updated to 3 tabs
    });
  }

  void _showEditTaskModal(Map<String, dynamic> task, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TaskModal(
          task: task,
          onSave: (updatedTask) async {
            _editTask(index, updatedTask);
          },
          isEdit: true,
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        );
      },
    ).then((value) {
      if (value == true) {
        _refreshWholePage(); // Full page refresh
      }
    });
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
                _formatTimestamp(message['created_at']!),
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
    List<File> selectedFiles = [];

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
       isScrollable: true,
      controller: _tabController,
      labelColor: Colors.amber,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Colors.amber,
      labelStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.normal,
      ),
      tabs: const [
        Tab(text: 'Processing or Detail'),
        Tab(text: 'Assignment /Task'),
        Tab(text: 'Comment/Chat'),// Comment / Chat tab is hidden from the TabBar but kept in TabBarView
      ],
    ),
    Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildProcessingOrDetailTab(filteredTasks),  // Tab 1
          _buildAssignmentorTaskTab(filteredTasks),    // Tab 2
          _buildChatAndConversationTab(isDarkMode),    // Tab 3 (accessible by swiping)
        ],
      ),
    ),
  ],
),

    );
  }

Widget _buildAssignmentorTaskTab(List<Map<String, dynamic>> filteredTasks) {
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
              onPressed: () => _showAddTaskModal(),
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
                child: _buildAssignmentTaskCard(filteredTasks[index], index),
              );
            },
          ),
        ),
      ),
    ],
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
              onPressed: () => _showAddTaskModal(),
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
                child: _buildProcessingTaskCard(filteredTasks[index], index),
              );
            },
          ),
        ),
      ),
    ],
  );
}
Widget _buildAssignmentTaskCard(Map<String, dynamic> task, int index) {
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
          Text(
            task['title'] ?? 'No Title',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
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
          _buildIconTextRow(
            icon: Icons.timelapse,
            label: 'Days Remaining: $daysRemaining',
            iconColor: Colors.greenAccent,
          ),
          const SizedBox(height: 12),
          Text(
            task['description'] ?? 'No Description',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Hardcoded avatars as per Figma design
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3, // Show 3 placeholders for now
              itemBuilder: (context, memberIndex) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.account_circle, size: 30, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildProcessingTaskCard(Map<String, dynamic> task, int index) {
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
          // Status row with dynamic clock icon color
          Row(
            children: [
              const SizedBox(width: 8),
              const Text(
                'Status:',
                style: TextStyle(
                  color: Colors.black87, // Main status label color
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.access_time, // Clock icon
                color: progressColors[task['status']] ?? Colors.black, // Dynamic color based on task status
                size: 16,
              ),
              const SizedBox(width: 2),
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
          // Task title with "Title:" label
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Title: ', // Add the "Title:" label
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 20,
                  ),
                ),
                TextSpan(
                  text: task['title'] ?? 'No Title', // Display the actual task title
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Task description
          Text(
            task['description'] ?? 'No Description',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Start and Due date row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconTextRow(
                icon: Icons.calendar_today,
                label: 'Date: ${task['start_date'] ?? 'N/A'} - ${task['due_date'] ?? 'N/A'}',
                iconColor: Colors.orangeAccent,
              ),
              const SizedBox(height: 8),
              _buildIconTextRow(
                icon: Icons.access_time_outlined,
                label: 'Time: 09:00 AM - 12:00 PM', // Adjust the time display dynamically if needed
                iconColor: progressColors[task['status']] ?? Colors.redAccent, // Dynamic time icon color
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Days remaining section
          _buildIconTextRow(
            icon: Icons.timelapse,
            label: 'Days Remaining: $daysRemaining',
            iconColor: Colors.greenAccent,
          ),
        ],
      ),
    ),
  );
}




Widget _buildIconTextRow({required IconData icon, required String label, required Color iconColor}) {
  return Row(
    children: [
      Icon(icon, color: iconColor, size: 18),
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


// Widget _buildAssignmentTaskCard(Map<String, dynamic> task, int index) {
//   final progressColors = {
//     'Pending': Colors.orange,
//     'Processing': Colors.blue,
//     'Finished': Colors.green,
//   };

//   final startDate = DateTime.parse(task['start_date'] ?? DateTime.now().toIso8601String());
//   final dueDate = DateTime.parse(task['due_date'] ?? DateTime.now().toIso8601String());
//   final daysRemaining = dueDate.difference(startDate).inDays;

//   return Container(
//     margin: const EdgeInsets.symmetric(vertical: 10.0),
//     decoration: BoxDecoration(
//       gradient: const LinearGradient(
//         colors: [
//           Color(0xFFE0E0F0),
//           Color(0xFFF7F7FF),
//           Color(0xFFFFFFFF),
//         ],
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter,
//       ),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.1),
//           blurRadius: 8,
//           spreadRadius: 1,
//           offset: const Offset(4, 4),
//         ),
//       ],
//       borderRadius: BorderRadius.circular(16.0),
//     ),
//     child: Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 Icons.circle,
//                 color: progressColors[task['status']] ?? Colors.black,
//                 size: 14,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 task['status'] ?? 'Unknown',
//                 style: TextStyle(
//                   color: progressColors[task['status']] ?? Colors.black,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//               const Spacer(),
//               const Icon(
//                 Icons.more_vert,
//                 color: Colors.black54,
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             task['title'] ?? 'No Title',
//             style: const TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildIconTextRow(
//                 icon: Icons.calendar_today,
//                 label: 'Start Date: ${task['start_date'] ?? 'N/A'}',
//                 iconColor: Colors.orangeAccent,
//               ),
//               const SizedBox(height: 8),
//               _buildIconTextRow(
//                 icon: Icons.calendar_today_outlined,
//                 label: 'Due Date: ${task['due_date'] ?? 'N/A'}',
//                 iconColor: Colors.redAccent,
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           _buildIconTextRow(
//             icon: Icons.timelapse,
//             label: 'Days Remaining: $daysRemaining',
//             iconColor: Colors.greenAccent,
//           ),
//           const SizedBox(height: 12),
//           Text(
//             task['description'] ?? 'No Description',
//             style: const TextStyle(
//               color: Colors.black54,
//               fontSize: 14,
//               height: 1.5,
//             ),
//           ),
//           const SizedBox(height: 12),
          
//           SizedBox(
//             height: 40,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: task['members']?.length ?? 3, 
//               itemBuilder: (context, memberIndex) {
//                 final member = task['members'] != null && memberIndex < task['members'].length
//                     ? task['members'][memberIndex]
//                     : null; // Use member data if available

//                 final imageUrl = member?['image'] ?? 'https://example.com/default_avatar.jpg';

//                 return Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 4.0),
//                   child: CircleAvatar(
//                     backgroundImage: NetworkImage(imageUrl),
//                     radius: 20,
//                     onBackgroundImageError: (exception, stackTrace) {
//                       print('Error loading member image: $exception');
//                     },
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }


// Widget _buildProcessingTaskCard(Map<String, dynamic> task, int index) {
  
//   return _buildAssignmentTaskCard(task, index); 
// }

// // Helper method for building icon-text rows
// Widget _buildIconTextRow({required IconData icon, required String label, required Color iconColor}) {
//   return Row(
//     children: [
//       Icon(icon, color: iconColor, size: 18),
//       const SizedBox(width: 8),
//       Expanded(
//         child: Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             color: Colors.black87,
//           ),
//         ),
//       ),
//     ],
//   );
// }


  // Widget _buildIconTextRow({required IconData icon, required String label, Color? iconColor}) {
  //   return Row(
  //     children: [
  //       Icon(icon, color: iconColor ?? Colors.black54, size: 18), 
  //       const SizedBox(width: 8),
  //       Expanded(
  //         child: Text(
  //           label,
  //           style: const TextStyle(
  //             fontSize: 14,
  //             color: Colors.black87,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

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

                // Attachments Section
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: task['files'].map<Widget>((filePath) {
                      final fileExtension = filePath.split('.').last.toLowerCase();

                      return GestureDetector(
                        onTap: () {
                          print('Opening PDF at: ${widget.baseUrl}/$filePath'); // Debugging line
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
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Assigned Members:'),
                const SizedBox(height: 10),
                task['members'] != null && task['members'].isNotEmpty
                    ? Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: List.generate(task['members'].length, (index) {
                          final member = task['members'][index];
                          return Column(
                            children: [
                              CircleAvatar(
                                backgroundImage: member['image'] != null && member['image'].isNotEmpty
                                    ? NetworkImage(member['image'])
                                    : const NetworkImage('https://demo-application-api.flexiflows.co/default_avatar.jpg'),
                                radius: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                member['name'] ?? 'No Name',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          );
                        }),
                      )
                    : const Text('No members assigned', style: TextStyle(color: Colors.grey)),
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
                Navigator.pop(context);
                _showEditTaskModal(task, index); // Open the edit modal
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
        _messages.removeWhere((message) => message['comment_id'] == commentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted successfully')),
      );
    } else {
      final responseData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: ${responseData['error'] ?? 'Unknown error'}')),
      );
    }
  }

  void _showTaskModal({Map<String, dynamic>? task, int? index, bool isEdit = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TaskModal(
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

  Future<void> _addTask(Map<String, dynamic> taskData) async {
    try {
      // Step 1: Create the task (POST)
      final asId = await _workTrackingService.addAssignment(widget.projectId, {
        'status_id': taskData['status_id'],
        'title': taskData['title'],
        'descriptions': taskData['descriptions'],
        'memberDetails': taskData['memberDetails'], // If members are part of initial task creation
      });

      if (asId != null) {
        // Step 2: Upload files (PUT) - If files exist
        if (taskData['files'] != null && taskData['files'].isNotEmpty) {
          for (var file in taskData['files']) {
            await _workTrackingService.addFilesToAssignment(asId, [file]);
          }
        }

        // Step 3: Add members (Optional - depending on your flow)
        if (taskData['members'] != null && taskData['members'].isNotEmpty) {
          await _workTrackingService.addMembersToAssignment(asId, taskData['members']);
        }

        // After all steps are complete, show success and refresh the project data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully with files and members!')),
        );

        // Refresh the project/task list
        _fetchProjectData();

      } else {
        // Handle error creating the task
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create task')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding task: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding task: $e')),
      );
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
      case 'Finished':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}


