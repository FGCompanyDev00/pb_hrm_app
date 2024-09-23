
// // import 'dart:convert';
// // import 'dart:io';
// // import 'package:file_picker/file_picker.dart';
// // import 'package:flutter/foundation.dart';
// // import 'package:flutter/material.dart';
// // import 'package:image_picker/image_picker.dart';
// // import 'package:intl/intl.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:pb_hrsystem/services/assignment_service.dart';
// // import 'package:pb_hrsystem/services/image_viewer.dart';
// // import 'package:provider/provider.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:pb_hrsystem/services/work_tracking_service.dart';
// // import 'package:pb_hrsystem/theme/theme.dart';
// // import 'package:flutter_pdfview/flutter_pdfview.dart';

// // class ProjectManagementPage extends StatefulWidget {
// //   final String projectId;
// //   final String baseUrl;

// //   const ProjectManagementPage({super.key, required this.projectId, required this.baseUrl});

// //   @override
// //   _ProjectManagementPageState createState() => _ProjectManagementPageState();
// // }

// // class _ProjectManagementPageState extends State<ProjectManagementPage> with SingleTickerProviderStateMixin {
// //   List<Map<String, dynamic>> _tasks = [];
// //   List<Map<String, dynamic>> _messages = [];
// //   String _selectedStatus = 'All Status';
// //   final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Finished'];
// //   late TabController _tabController;
// //   final TextEditingController _messageController = TextEditingController();
// //   String _currentUserId = '';
// //   final WorkTrackingService _workTrackingService = WorkTrackingService();
// //   final AssignmentService _assignmentService = AssignmentService();
// //   final ScrollController _scrollController = ScrollController();

// //   @override
// //   void initState() {
// //     super.initState();
// //     _tabController = TabController(length: 2, vsync: this);
// //     _loadUserData();
// //     _fetchProjectData();
// //     _loadChatMessages();
// //     _loadCurrentUser();
// //   }

// //   Future<void> _loadUserData() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     setState(() {
// //       _currentUserId = prefs.getString('userId') ?? '';
// //     });
// //   }

// //   Future<void> _fetchProjectData() async {
// //     try {
// //       final tasks = await _workTrackingService.fetchAssignments(widget.projectId);
// //       setState(() {
// //         _tasks = tasks.where((task) => task['proj_id'] == widget.projectId).map((task) {
// //           return {
// //             'id': task['id'],
// //             'as_id': task['as_id'], 
// //             'title': task['title'] ?? 'No Title',
// //             'status': task['s_name'] ?? 'Unknown',
// //             'start_date': task['created_at']?.substring(0, 10) ?? 'N/A',
// //             'due_date': task['updated_at']?.substring(0, 10) ?? 'N/A',
// //             'description': task['description'] ?? 'No Description',
// //             'files': task['file_name'] != null ? task['file_name'].split(',') : [],
// //             'members': task['members'] ?? [],
// //           };
// //         }).toList();
// //       });
// //     } catch (e) {
// //       if (kDebugMode) {
// //         print('Failed to load project data: $e');
// //       }
// //     }
// //   }

// //   void _showAddTaskModal() {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return _TaskModal(
// //           onSave: (newTask) async {
// //             _addTask(newTask);
// //           },
// //           isEdit: false,
// //           projectId: widget.projectId,
// //           baseUrl: widget.baseUrl,
// //         );
// //       },
// //     ).then((value) {
// //       if (value == true) {
// //         _refreshWholePage(); // Full page refresh
// //       }
// //     });
// //   }


// //   void _refreshWholePage() {
// //     setState(() {
// //       _fetchProjectData();
// //       _tabController = TabController(length: 2, vsync: this);
// //     });
// //   }

// //   void _showEditTaskModal(Map<String, dynamic> task, int index) {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return _TaskModal(
// //           task: task,
// //           onSave: (updatedTask) async {
// //             _editTask(index, updatedTask);
// //           },
// //           isEdit: true,
// //           projectId: widget.projectId,
// //           baseUrl: widget.baseUrl,
// //         );
// //       },
// //     ).then((value) {
// //       if (value == true) {
// //         _refreshWholePage(); // Full page refresh
// //       }
// //     });
// //   }

// //   void _scrollToBottom() {
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       if (_scrollController.hasClients) {
// //         _scrollController.jumpTo(_scrollController.position.minScrollExtent); // Jump to the bottom
// //       }
// //     });
// //   }

// //   Future<void> _loadChatMessages() async {
// //     try {
// //       final messages = await _workTrackingService.fetchChatMessages(widget.projectId);
// //       setState(() {
// //         _messages = messages.map((message) {
// //           return {
// //             ...message,
// //             'createBy_name': message['created_by'] == _currentUserId ? 'You' : message['createBy_name'],
// //           };
// //         }).toList();
// //       });
// //       _scrollToBottom(); // Ensure scrolling to the bottom after messages are loaded
// //     } catch (e) {
// //       if (kDebugMode) {
// //         print('Failed to load chat messages: $e');
// //       }
// //     }
// //   }

// //   Widget _buildChatAndConversationTab(bool isDarkMode) {
// //     return Column(
// //       children: [
// //         Expanded(
// //           child: ListView.builder(
// //             reverse: true, // Reverse the order of the list to show the latest message at the bottom
// //             controller: _scrollController,
// //             padding: const EdgeInsets.all(16.0),
// //             itemCount: _messages.length,
// //             itemBuilder: (context, index) {
// //               final message = _messages[index];
// //               final nextMessage = index + 1 < _messages.length ? _messages[index + 1] : null;

// //               // Check if the date of the current message is different from the next one (since list is reversed)
// //               final bool isNewDate = nextMessage == null ||
// //                   _formatDate(message['created_at']) != _formatDate(nextMessage['created_at']);

// //               return Column(
// //                 crossAxisAlignment: CrossAxisAlignment.stretch,
// //                 children: [
// //                   if (isNewDate) // Display date header
// //                     Center(
// //                       child: Padding(
// //                         padding: const EdgeInsets.symmetric(vertical: 8.0),
// //                         child: Text(
// //                           _formatDate(message['created_at']),
// //                           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
// //                         ),
// //                       ),
// //                     ),
// //                   _buildChatMessage(message, nextMessage, isDarkMode), // Message bubble
// //                 ],
// //               );
// //             },
// //           ),
// //         ),
// //         _buildChatInput(isDarkMode), // Chat input at the bottom
// //       ],
// //     );
// //   }

// //   String _formatDate(String timestamp) {
// //     final DateTime messageDate = DateTime.parse(timestamp);
// //     final DateTime now = DateTime.now();

// //     if (messageDate.year == now.year && messageDate.month == now.month && messageDate.day == now.day) {
// //       return 'Today';
// //     } else if (messageDate.year == now.year && messageDate.month == now.month && messageDate.day == now.day - 1) {
// //       return 'Yesterday';
// //     } else {
// //       return DateFormat('dd MMM yyyy').format(messageDate);
// //     }
// //   }

// //   String _formatTimestamp(String timestamp) {
// //     final DateTime messageTime = DateTime.parse(timestamp);
// //     return DateFormat('hh:mm a').format(messageTime); // Time in hh:mm AM/PM format
// //   }

// //   Widget _buildChatMessage(Map<String, dynamic> message, Map<String, dynamic>? nextMessage, bool isDarkMode) {
// //     final bool isSentByMe = message['created_by'] == _currentUserId;
// //     final String senderName = isSentByMe ? 'You' : message['createBy_name'] ?? 'Unknown'; // Replace current user name with 'You'

// //     final Color messageColor = isSentByMe
// //         ? Colors.blue.shade200 // Your own messages (light blue)
// //         : _assignChatBubbleColor(message['created_by']); // Different color for others

// //     final Color textColor = isDarkMode ? Colors.white : Colors.black;
// //     final Alignment messageAlignment = isSentByMe ? Alignment.centerRight : Alignment.centerLeft;

// //     return GestureDetector(
// //       onTap: () {
// //         if (isSentByMe) {
// //           _showDeleteConfirmation(message['comment_id']); // Only allow deletion of own messages
// //         }
// //       },
// //       child: Align(
// //         alignment: messageAlignment,
// //         child: Container(
// //           margin: const EdgeInsets.symmetric(vertical: 8.0),
// //           padding: const EdgeInsets.all(12.0),
// //           decoration: BoxDecoration(
// //             color: messageColor,
// //             borderRadius: BorderRadius.only(
// //               topLeft: isSentByMe ? const Radius.circular(12.0) : const Radius.circular(0),
// //               topRight: isSentByMe ? const Radius.circular(0) : const Radius.circular(12.0),
// //               bottomLeft: const Radius.circular(12.0),
// //               bottomRight: const Radius.circular(12.0),
// //             ),
// //           ),
// //           child: Column(
// //             crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
// //             children: [
// //               if (!isSentByMe) // Only show name for others' messages
// //                 Text(
// //                   senderName,
// //                   style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold),
// //                 ),
// //               const SizedBox(height: 4),
// //               Text(
// //                 message['comments'] ?? '',
// //                 style: TextStyle(color: textColor, fontSize: 16),
// //               ),
// //               const SizedBox(height: 4),
// //               Text(
// //                 _formatTimestamp(message['created_at']),
// //                 style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Color _assignChatBubbleColor(String userId) {
// //     final List<Color> colors = [
// //       Colors.green.shade100,
// //       Colors.orange.shade100,
// //       Colors.purple.shade100,
// //       Colors.red.shade100,
// //       Colors.yellow.shade100,
// //     ];

// //     final int hashValue = userId.hashCode % colors.length;
// //     return colors[hashValue];
// //   }

// //   Widget _buildChatInput(bool isDarkMode) {
// //     final Color backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
// //     final Color textColor = isDarkMode ? Colors.white : Colors.black;
// //     final Color sendButtonColor = isDarkMode ? Colors.green[300]! : Colors.green;

// //     return Padding(
// //       padding: const EdgeInsets.all(16.0),
// //       child: Container(
// //         padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
// //         decoration: BoxDecoration(
// //           color: backgroundColor,
// //           borderRadius: BorderRadius.circular(30.0),
// //           boxShadow: [
// //             BoxShadow(
// //               color: Colors.black.withOpacity(0.1),
// //               spreadRadius: 1,
// //               blurRadius: 8,
// //               offset: const Offset(2, 4),
// //             ),
// //           ],
// //         ),
// //         child: Row(
// //           children: [
// //             Expanded(
// //               child: TextField(
// //                 controller: _messageController,
// //                 decoration: InputDecoration(
// //                   hintText: 'Type a message...',
// //                   hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
// //                   border: InputBorder.none,
// //                 ),
// //                 style: TextStyle(color: textColor),
// //                 maxLines: null,
// //               ),
// //             ),
// //             const SizedBox(width: 8),
// //             CircleAvatar(
// //               radius: 25,
// //               backgroundColor: sendButtonColor,
// //               child: IconButton(
// //                 icon: const Icon(Icons.send, color: Colors.white),
// //                 onPressed: () {
// //                   if (_messageController.text.isNotEmpty) {
// //                     _sendMessage(_messageController.text);
// //                   }
// //                 },
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   String _currentUserName = '';

// //   Future<void> _loadCurrentUser() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final token = prefs.getString('token');

// //     if (token == null) {
// //       // Handle token missing case
// //       return;
// //     }

// //     final response = await http.get(
// //       Uri.parse('${widget.baseUrl}/api/display/me'),
// //       headers: {
// //         'Authorization': 'Bearer $token',
// //       },
// //     );

// //     if (response.statusCode == 200) {
// //       final data = jsonDecode(response.body);
// //       if (data['results'] != null && data['results'].isNotEmpty) {
// //         setState(() {
// //           _currentUserId = data['results'][0]['id'];  // Set current user ID
// //           _currentUserName = data['results'][0]['employee_name']; // Set current user name
// //         });
// //       }
// //     }
// //   }

// //   Future<void> _sendMessage(String message) async {
// //     try {
// //       await _workTrackingService.sendChatMessage(widget.projectId, message);
// //       _addMessage(message);
// //     } catch (e) {
// //       if (kDebugMode) {
// //         print('Failed to send message: $e');
// //       }
// //     }
// //   }

// //   void _showDeleteConfirmation(String commentId) {
// //     print('Comment ID to delete: $commentId');  // For debugging

// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           title: const Text('Delete Message'),
// //           content: const Text('Would you like to delete this message?'),
// //           actions: [
// //             TextButton(
// //               onPressed: () {
// //                 Navigator.of(context).pop(); // Close the modal
// //               },
// //               child: const Text('No'),
// //             ),
// //             ElevatedButton(
// //               onPressed: () {
// //                 Navigator.of(context).pop(); // Close the modal
// //                 _deleteMessage(commentId); // Delete the message
// //               },
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.red,
// //               ),
// //               child: const Text('Yes'),
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   void _addMessage(String message) {
// //     final DateTime now = DateTime.now();
// //     setState(() {
// //       _messages.insert(0, {
// //         'comments': message,
// //         'created_at': now.toIso8601String(),
// //         'createBy_name': 'You',
// //         'created_by': _currentUserId,
// //       });
// //     });
// //     _messageController.clear();
// //     _scrollToBottom();
// //   }

// //   @override
// //   void dispose() {
// //     _messageController.dispose();
// //     _scrollController.dispose();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final themeNotifier = Provider.of<ThemeNotifier>(context);
// //     final bool isDarkMode = themeNotifier.isDarkMode;

// //     List<Map<String, dynamic>> filteredTasks = _tasks.where((task) => _selectedStatus == 'All Status' || task['status'] == _selectedStatus).toList();
// //     List<File> selectedFiles = [];

// //     return Scaffold(
// //       appBar: PreferredSize(
// //         preferredSize: const Size.fromHeight(85.0),
// //         child: AppBar(
// //           automaticallyImplyLeading: true,
// //           backgroundColor: Colors.transparent,
// //           elevation: 0,
// //           flexibleSpace: ClipRRect(
// //             borderRadius: const BorderRadius.only(
// //               bottomLeft: Radius.circular(20),
// //               bottomRight: Radius.circular(20),
// //             ),
// //             child: Container(
// //               decoration: const BoxDecoration(
// //                 image: DecorationImage(
// //                   image: AssetImage('assets/background.png'),
// //                   fit: BoxFit.cover,
// //                 ),
// //               ),
// //             ),
// //           ),

// //           leading: Padding(
// //             padding: const EdgeInsets.only(top: 25.0),
// //             child: IconButton(
// //               icon: const Icon(Icons.arrow_back, color: Colors.black),
// //               onPressed: () {
// //                 Navigator.pop(context);
// //               },
// //             ),
// //           ),

// //           title: const Padding(
// //             padding: EdgeInsets.only(top: 34.0),
// //             child: Row(
// //               mainAxisAlignment: MainAxisAlignment.start,
// //               children: [
// //                 Spacer(flex: 2),
// //                 Text(
// //                   'Work Tracking',
// //                   style: TextStyle(
// //                     color: Colors.black,
// //                     fontWeight: FontWeight.bold,
// //                     fontSize: 24,
// //                   ),
// //                 ),
// //                 Spacer(flex: 4),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),

// //       body: Column(
// //         children: [
// //           TabBar(
// //             controller: _tabController,
// //             labelColor: Colors.amber,
// //             unselectedLabelColor: Colors.grey,
// //             indicatorColor: Colors.amber,
// //             labelStyle: const TextStyle(
// //               fontSize: 16,
// //               fontWeight: FontWeight.bold,
// //             ),
// //             unselectedLabelStyle: const TextStyle(
// //               fontSize: 16,
// //               fontWeight: FontWeight.normal,
// //             ),
// //             tabs: const [
// //               Tab(text: 'Assignment / Task'),
// //               Tab(text: 'Comment / Chat'),
// //             ],
// //           ),
// //           Expanded(
// //             child: TabBarView(
// //               controller: _tabController,
// //               children: [
// //                 _buildProcessingOrDetailTab(filteredTasks),
// //                 _buildChatAndConversationTab(isDarkMode),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildProcessingOrDetailTab(List<Map<String, dynamic>> filteredTasks) {
// //     final themeNotifier = Provider.of<ThemeNotifier>(context);
// //     final bool isDarkMode = themeNotifier.isDarkMode;

// //     return Column(
// //       children: [
// //         Padding(
// //           padding: const EdgeInsets.all(16.0),
// //           child: Row(
// //             children: [
// //               Expanded(
// //                 child: AnimatedContainer(
// //                   duration: const Duration(milliseconds: 300),
// //                   curve: Curves.easeInOut,
// //                   decoration: BoxDecoration(
// //                     gradient: isDarkMode
// //                         ? const LinearGradient(
// //                       colors: [Color(0xFF424242), Color(0xFF303030)],
// //                       begin: Alignment.topLeft,
// //                       end: Alignment.bottomRight,
// //                     )
// //                         : const LinearGradient(
// //                       colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
// //                       begin: Alignment.topLeft,
// //                       end: Alignment.bottomRight,
// //                     ),
// //                     boxShadow: [
// //                       BoxShadow(
// //                         color: Colors.black.withOpacity(0.1),
// //                         blurRadius: 10,
// //                         spreadRadius: 1,
// //                         offset: const Offset(1, 1),
// //                       ),
// //                     ],
// //                     borderRadius: BorderRadius.circular(12.0),
// //                   ),

// //                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
// //                   child: DropdownButtonHideUnderline(
// //                     child: DropdownButton<String>(
// //                       value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
// //                       icon: const Icon(Icons.arrow_downward, color: Colors.amber),
// //                       iconSize: 28,
// //                       elevation: 16,
// //                       dropdownColor: isDarkMode ? const Color(0xFF424242) : Colors.white,
// //                       style: TextStyle(
// //                         color: isDarkMode ? Colors.white : Colors.black87,
// //                         fontWeight: FontWeight.bold,
// //                         fontSize: 16,
// //                       ),
// //                       onChanged: (String? newValue) {
// //                         setState(() {
// //                           _selectedStatus = newValue!;
// //                         });
// //                       },
// //                       items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
// //                         return DropdownMenuItem<String>(
// //                           value: value,
// //                           child: Row(
// //                             children: [
// //                               Icon(Icons.circle, color: _getStatusColor(value), size: 14),
// //                               const SizedBox(width: 10),
// //                               Text(value),
// //                             ],
// //                           ),
// //                         );
// //                       }).toList(),
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //               const SizedBox(width: 8),
// //               IconButton(
// //                 icon: Container(
// //                   decoration: BoxDecoration(
// //                     shape: BoxShape.circle,
// //                     gradient: const LinearGradient(
// //                       colors: [Colors.greenAccent, Colors.teal],
// //                       begin: Alignment.topLeft,
// //                       end: Alignment.bottomRight,
// //                     ),
// //                     boxShadow: [
// //                       BoxShadow(
// //                         color: Colors.black.withOpacity(0.2),
// //                         blurRadius: 10,
// //                         spreadRadius: 1,
// //                         offset: const Offset(2, 4),
// //                       ),
// //                     ],
// //                   ),
// //                   padding: const EdgeInsets.all(10.0),
// //                   child: const Icon(
// //                     Icons.add,
// //                     color: Colors.white,
// //                     size: 20.0,
// //                   ),
// //                 ),
// //                 onPressed: () => _showAddTaskModal(),
// //               ),
// //             ],
// //           ),
// //         ),
// //         Expanded(
// //           child: RefreshIndicator(
// //             onRefresh: _fetchProjectData,
// //             child: ListView.builder(
// //               padding: const EdgeInsets.all(12.0),
// //               itemCount: filteredTasks.length,
// //               itemBuilder: (context, index) {
// //                 return GestureDetector(
// //                   onTap: () {
// //                     _showTaskViewModal(filteredTasks[index], index);
// //                   },
// //                   child: _buildTaskCard(filteredTasks[index], index),
// //                 );
// //               },
// //             ),
// //           ),
// //         ),
// //       ],
// //     );
// //   }

// //   Widget _buildTaskCard(Map<String, dynamic> task, int index) {
// //     final progressColors = {
// //       'Pending': Colors.orange,
// //       'Processing': Colors.blue,
// //       'Finished': Colors.green,
// //     };

// //     final startDate = DateTime.parse(task['start_date'] ?? DateTime.now().toIso8601String());
// //     final dueDate = DateTime.parse(task['due_date'] ?? DateTime.now().toIso8601String());
// //     final daysRemaining = dueDate.difference(startDate).inDays;

// //     return Container(
// //       margin: const EdgeInsets.symmetric(vertical: 10.0),
// //       decoration: BoxDecoration(
// //         gradient: const LinearGradient(
// //           colors: [
// //             Color(0xFFE0E0F0),
// //             Color(0xFFF7F7FF),
// //             Color(0xFFFFFFFF),
// //           ],
// //           begin: Alignment.topCenter,
// //           end: Alignment.bottomCenter,
// //         ),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withOpacity(0.1),
// //             blurRadius: 8,
// //             spreadRadius: 1,
// //             offset: const Offset(4, 4),
// //           ),
// //         ],
// //         borderRadius: BorderRadius.circular(16.0),
// //       ),
// //       child: Padding(
// //         padding: const EdgeInsets.all(16.0),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Row(
// //               children: [
// //                 Icon(
// //                   Icons.circle,
// //                   color: progressColors[task['status']] ?? Colors.black,
// //                   size: 14,
// //                 ),
// //                 const SizedBox(width: 8),
// //                 Text(
// //                   task['status'] ?? 'Unknown',
// //                   style: TextStyle(
// //                     color: progressColors[task['status']] ?? Colors.black,
// //                     fontWeight: FontWeight.bold,
// //                     fontSize: 16,
// //                   ),
// //                 ),
// //                 const Spacer(),
// //                 const Icon(
// //                   Icons.more_vert,
// //                   color: Colors.black54,
// //                 ),
// //               ],
// //             ),
// //             const SizedBox(height: 12),
// //             Text(
// //               task['title'] ?? 'No Title',
// //               style: const TextStyle(
// //                 fontSize: 20,
// //                 fontWeight: FontWeight.w600,
// //                 color: Colors.black87,
// //               ),
// //             ),
// //             const SizedBox(height: 12),
// //             Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 _buildIconTextRow(
// //                   icon: Icons.calendar_today,
// //                   label: 'Start Date: ${task['start_date'] ?? 'N/A'}',
// //                   iconColor: Colors.orangeAccent,
// //                 ),
// //                 const SizedBox(height: 8),
// //                 _buildIconTextRow(
// //                   icon: Icons.calendar_today_outlined,
// //                   label: 'Due Date: ${task['due_date'] ?? 'N/A'}',
// //                   iconColor: Colors.redAccent,
// //                 ),
// //               ],
// //             ),
// //             const SizedBox(height: 12),
// //             _buildIconTextRow(
// //               icon: Icons.timelapse,
// //               label: 'Days Remaining: $daysRemaining',
// //               iconColor: Colors.greenAccent,
// //             ),
// //             const SizedBox(height: 12),
// //             Text(
// //               task['description'] ?? 'No Description',
// //               style: const TextStyle(
// //                 color: Colors.black54,
// //                 fontSize: 14,
// //                 height: 1.5,
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildIconTextRow({required IconData icon, required String label, Color? iconColor}) {
// //     return Row(
// //       children: [
// //         Icon(icon, color: iconColor ?? Colors.black54, size: 18), 
// //         const SizedBox(width: 8),
// //         Expanded(
// //           child: Text(
// //             label,
// //             style: const TextStyle(
// //               fontSize: 14,
// //               color: Colors.black87,
// //             ),
// //           ),
// //         ),
// //       ],
// //     );
// //   }

// //   void _showTaskViewModal(Map<String, dynamic> task, int index) {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
// //           title: const Text('View Task'),
// //           content: SingleChildScrollView(
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text('Title: ${task['title'] ?? 'No Title'}', style: const TextStyle(fontWeight: FontWeight.bold)),
// //                 const SizedBox(height: 10),
// //                 Text('Status: ${task['status'] ?? 'Unknown'}', style: TextStyle(color: _getStatusColor(task['status'] ?? 'Unknown'))),
// //                 const SizedBox(height: 10),
// //                 Text('Start Date: ${task['start_date'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
// //                 const SizedBox(height: 10),
// //                 Text('Due Date: ${task['due_date'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
// //                 const SizedBox(height: 10),
// //                 Text('Description: ${task['description'] ?? 'No Description'}', style: const TextStyle(color: Colors.black87)),
// //                 const SizedBox(height: 10),
// //                 const Text('Attachments:'),
// //                 const SizedBox(height: 10),

// //                 // Attachments Section
// //                 SingleChildScrollView(
// //                   scrollDirection: Axis.horizontal,
// //                   child: Row(
// //                     children: task['files'].map<Widget>((filePath) {
// //                       final fileExtension = filePath.split('.').last.toLowerCase();

// //                       return GestureDetector(
// //                         onTap: () {
// //                           print('Opening PDF at: ${widget.baseUrl}/$filePath'); // Debugging line
// //                           if (fileExtension == 'pdf') {
// //                             Navigator.push(
// //                               context,
// //                               MaterialPageRoute(
// //                                 builder: (context) => PdfViewer(filePath: '${widget.baseUrl}/$filePath'),
// //                               ),
// //                             );
// //                           } else if (['jpg', 'jpeg', 'png'].contains(fileExtension)) {
// //                             Navigator.push(
// //                               context,
// //                               MaterialPageRoute(
// //                                 builder: (context) => ImageViewer(imagePath: '${widget.baseUrl}/$filePath'),
// //                               ),
// //                             );
// //                           } else {
// //                             ScaffoldMessenger.of(context).showSnackBar(
// //                               const SnackBar(content: Text('Unsupported file format')),
// //                             );
// //                           }
// //                         },
// //                         child: Padding(
// //                           padding: const EdgeInsets.symmetric(vertical: 8.0),
// //                           child: Row(
// //                             children: [
// //                               Icon(fileExtension == 'pdf' ? Icons.picture_as_pdf : Icons.image),
// //                               const SizedBox(width: 8),
// //                               Text(filePath.split('/').last),
// //                             ],
// //                           ),
// //                         ),
// //                       );
// //                     }).toList(),
// //                   ),
// //                 ),
// //                 const SizedBox(height: 20),

// //                 const Text('Assigned Members:'),
// //                 const SizedBox(height: 10),
// //                 task['members'] != null && task['members'].isNotEmpty
// //                     ? Wrap(
// //                   spacing: 8.0,
// //                   children: task['members'].map<Widget>((member) {
// //                     return GestureDetector(
// //                       onTap: () {
// //                         showDialog(
// //                           context: context,
// //                           builder: (BuildContext context) {
// //                             return AlertDialog(
// //                               content: Text(member['name'] ?? 'No Name'),
// //                               actions: [
// //                                 TextButton(
// //                                   onPressed: () {
// //                                     Navigator.pop(context);
// //                                   },
// //                                   child: const Text('Close'),
// //                                 ),
// //                               ],
// //                             );
// //                           },
// //                         );
// //                       },
// //                       child: Column(
// //                         children: [
// //                           CircleAvatar(
// //                             backgroundImage: member['image'] != null && member['image'].isNotEmpty
// //                                 ? NetworkImage(member['image'])
// //                                 : const NetworkImage('https://demo-application-api.flexiflows.co/default_avatar.jpg'),
// //                             radius: 24,
// //                           ),
// //                           const SizedBox(height: 4),
// //                           Text(
// //                             member['name'] ?? 'No Name',
// //                             style: const TextStyle(fontSize: 12),
// //                             overflow: TextOverflow.ellipsis,
// //                             maxLines: 1,
// //                           ),
// //                         ],
// //                       ),
// //                     );
// //                   }).toList(),
// //                 )
// //                     : const Text('No members assigned', style: TextStyle(color: Colors.grey)),
// //               ],
// //             ),
// //           ),
// //           actions: [
// //             TextButton(
// //               onPressed: () => Navigator.pop(context),
// //               child: const Text('Close'),
// //             ),
// //             ElevatedButton(
// //               onPressed: () {
// //                 Navigator.pop(context);
// //                 _showEditTaskModal(task, index); // Open the edit modal
// //               },
// //               style: ElevatedButton.styleFrom(
// //                 foregroundColor: Colors.black,
// //                 backgroundColor: Colors.amber,
// //               ),
// //               child: const Text('Edit'),
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   Future<void> _deleteMessage(String commentId) async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final token = prefs.getString('token');

// //     if (token == null) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text('Token is null. Please log in again.')),
// //       );
// //       return;
// //     }

// //     final url = Uri.parse('${widget.baseUrl}/api/work-tracking/project-comments/delete/$commentId');

// //     final response = await http.put(
// //       url,
// //       headers: {
// //         'Authorization': 'Bearer $token',
// //         'Content-Type': 'application/json',
// //       },
// //     );

// //     if (response.statusCode == 200) {
// //       setState(() {
// //         _messages.removeWhere((message) => message['comment_id'] == commentId);
// //       });
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text('Message deleted successfully')),
// //       );
// //     } else {
// //       final responseData = jsonDecode(response.body);
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Failed to delete message: ${responseData['error'] ?? 'Unknown error'}')),
// //       );
// //     }
// //   }

// //   void _showTaskModal({Map<String, dynamic>? task, int? index, bool isEdit = false}) {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return _TaskModal(
// //           task: task,
// //           onSave: (newTask) {
// //             if (task != null && index != null) {
// //               _editTask(index, newTask);
// //             } else {
// //               _addTask(newTask);
// //             }
// //           },
// //           isEdit: isEdit,
// //           projectId: widget.projectId,
// //           baseUrl: widget.baseUrl,
// //         );
// //       },
// //     );
// //   }

// //   void _editTask(int index, Map<String, dynamic> updatedTask) {
// //     setState(() {
// //       _tasks[index] = updatedTask;
// //     });
// //   }

// //   Future<void> _addTask(Map<String, dynamic> taskData) async {
// //     try {
// //       // Step 1: Create the task (POST)
// //       final asId = await _workTrackingService.addAssignment(widget.projectId, {
// //         'status_id': taskData['status_id'],
// //         'title': taskData['title'],
// //         'descriptions': taskData['descriptions'],
// //         'memberDetails': taskData['memberDetails'], // If members are part of initial task creation
// //       });

// //       if (asId != null) {
// //         // Step 2: Upload files (PUT) - If files exist
// //         if (taskData['files'] != null && taskData['files'].isNotEmpty) {
// //           for (var file in taskData['files']) {
// //             await _workTrackingService.addFilesToAssignment(asId, [file]);
// //           }
// //         }

// //         // Step 3: Add members (Optional - depending on your flow)
// //         if (taskData['members'] != null && taskData['members'].isNotEmpty) {
// //           await _workTrackingService.addMembersToAssignment(asId, taskData['members']);
// //         }

// //         // After all steps are complete, show success and refresh the project data
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Task created successfully with files and members!')),
// //         );

// //         // Refresh the project/task list
// //         _fetchProjectData();

// //       } else {
// //         // Handle error creating the task
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Failed to create task')),
// //         );
// //       }
// //     } catch (e) {
// //       if (kDebugMode) {
// //         print('Error adding task: $e');
// //       }
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Error adding task: $e')),
// //       );
// //     }
// //   }

// //   Future<void> _addMembersToAssignment(String asId, List<Map<String, dynamic>> members) async {
// //     try {
// //       await _workTrackingService.addMembersToAssignment(asId, members);
// //     } catch (e) {
// //       if (kDebugMode) {
// //         print('Failed to add members to assignment: $e');
// //       }
// //     }
// //   }

// //   Color _getStatusColor(String status) {
// //     switch (status) {
// //       case 'Pending':
// //         return Colors.orange;
// //       case 'Processing':
// //         return Colors.blue;
// //       case 'Finishedr':
// //         return Colors.green;
// //       default:
// //         return Colors.black;
// //     }
// //   }
// // }

// // class _TaskModal extends StatefulWidget {
// //   final Map<String, dynamic>? task;
// //   final Function(Map<String, dynamic>) onSave;
// //   final bool isEdit;
// //   final String projectId;
// //   final String baseUrl;

// //   static const List<Map<String, dynamic>> statusOptions = [
// //     {'id': '40d2ba5e-a978-47ce-bc48-caceca8668e9', 'name': 'Pending'},
// //     {'id': '0a8d93f0-1c05-42b2-8e56-984a578ef077', 'name': 'Processing'},
// //     {'id': 'e35569eb-75e1-4005-9232-bfb57303b8b3', 'name': 'Finished'},
// //   ];

// //   const _TaskModal({
// //     this.task,
// //     required this.onSave,
// //     this.isEdit = false,
// //     required this.projectId,
// //     required this.baseUrl,
// //   });

// //   @override
// //   __TaskModalState createState() => __TaskModalState();
// // }

// // class CustomAppBarClipper extends CustomClipper<Path> {
// //   @override
// //   Path getClip(Size size) {
// //     Path path = Path();
// //     path.lineTo(0.0, size.height - 10);
// //     path.quadraticBezierTo(
// //         size.width / 2, size.height, size.width, size.height - 10);
// //     path.lineTo(size.width, 0.0);
// //     path.close();
// //     return path;
// //   }

// //   @override
// //   bool shouldReclip(CustomClipper<Path> oldClipper) {
// //     return false;
// //   }
// // }

// // class __TaskModalState extends State<_TaskModal> {
// //   late TextEditingController _titleController;
// //   late TextEditingController _startDateController;
// //   late TextEditingController _dueDateController;
// //   late TextEditingController _descriptionController;
// //   late TextEditingController _memberDetailsController;
// //   late TextEditingController _fileController;
// //   String _selectedStatus = 'Pending';
// //   final ImagePicker _picker = ImagePicker();
// //   final List<File> _files = [];
// //   List<Map<String, dynamic>> _selectedPeople = [];
// //   final _formKey = GlobalKey<FormState>();

// //   final WorkTrackingService _workTrackingService = WorkTrackingService();

// //   @override
// //   void initState() {
// //     super.initState();

// //     _titleController = TextEditingController(text: widget.task?['title'] ?? '');
// //     _startDateController = TextEditingController(text: widget.task?['start_date'] ?? '');
// //     _dueDateController = TextEditingController(text: widget.task?['due_date'] ?? '');
// //     _descriptionController = TextEditingController(text: widget.task?['description'] ?? '');
// //     _memberDetailsController = TextEditingController();
// //     _fileController = TextEditingController();

// //     _selectedStatus = widget.task?['status'] ?? _TaskModal.statusOptions.first['id'];

// //     if (widget.isEdit) {
// //       _fetchAssignmentMembers();
// //     }
// //   }

// //   Future<void> _fetchAssignmentMembers() async {
// //     try {
// //       final members = await _workTrackingService.fetchAssignmentMembers(widget.projectId);
// //       setState(() {
// //         _selectedPeople = members;
// //       });
// //     } catch (e) {
// //       if (kDebugMode) {
// //         print('Failed to load assignment members: $e');
// //       }
// //     }
// //   }

// //   @override
// //   void dispose() {
// //     _titleController.dispose();
// //     _startDateController.dispose();
// //     _dueDateController.dispose();
// //     _descriptionController.dispose();
// //     _memberDetailsController.dispose();
// //     _fileController.dispose();
// //     super.dispose();
// //   }

// //   // // Future<void> _selectStartDate(BuildContext context) async {
// //   // //   final DateTime? picked = await showDatePicker(
// //   // //     context: context,
// //   // //     initialDate: DateTime.now(),
// //   // //     firstDate: DateTime(2000),
// //   // //     lastDate: DateTime(2101),
// //   // //   );
// //   // //   if (picked != null) {
// //   // //     setState(() {
// //   // //       _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
// //   // //     });
// //   // //   }
// //   // // }
// //   // //
// //   // // Future<void> _selectDueDate(BuildContext context) async {
// //   // //   final DateTime? picked = await showDatePicker(
// //   // //     context: context,
// //   // //     initialDate: DateTime.now(),
// //   // //     firstDate: DateTime(2000),
// //   // //     lastDate: DateTime(2101),
// //   // //   );
// //   // //   if (picked != null && picked.isAfter(DateTime.parse(_startDateController.text))) {
// //   // //     setState(() {
// //   // //       _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
// //   // //     });
// //   // //   } else {
// //   // //     ScaffoldMessenger.of(context).showSnackBar(
// //   // //       const SnackBar(content: Text('Due date must be after start date')),
// //   // //     );
// //   // //   }
// //   // }

// //   final List<File> _selectedFiles = [];

// // // Function to pick files and add them to the _files list
// //   Future<void> _pickFile() async {
// //     FilePickerResult? result = await FilePicker.platform.pickFiles(
// //       allowMultiple: true,
// //       type: FileType.custom,
// //       allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'mp4'],
// //     );

// //     // If the user picks a file, add it to the _files list
// //     if (result != null) {
// //       setState(() {
// //         _files.addAll(result.paths.map((path) => File(path!)).toList());
// //       });
// //     } else {
// //       // If no file is selected, show a message
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text('No file selected')),
// //       );
// //     }
// //   }

// // // Function to remove a file from the _files list
// //   void _removeFile(File file) {
// //     setState(() {
// //       _files.remove(file);
// //     });
// //   }

// //   Future<void> _saveTask() async {
// //     if (_formKey.currentState!.validate()) {
// //       final prefs = await SharedPreferences.getInstance();
// //       final token = prefs.getString('token');

// //       if (token == null) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Token is null. Please log in again.')),
// //         );
// //         return;
// //       }

// //       // Prepare task data for both adding and editing
// //       final taskData = {
// //         'status_id': _selectedStatus,
// //         'title': _titleController.text,
// //         'descriptions': _descriptionController.text,
// //         'memberDetails': jsonEncode([
// //           {'employee_id': '12345', 'role': 'Manager'}, // Example memberDetails structure
// //           {'employee_id': '67890', 'role': 'Developer'}
// //         ]),
// //       };

// //       try {
// //         // Check if it's an edit action
// //         if (widget.isEdit && widget.task != null) {
// //           // Edit Task API (PUT)
// //           final response = await http.put(
// //             Uri.parse('${widget.baseUrl}/api/work-tracking/ass/update/${widget.task!['as_id']}'),
// //             headers: {
// //               'Authorization': 'Bearer $token',
// //               'Content-Type': 'application/json',
// //             },
// //             body: jsonEncode(taskData),
// //           );

// //           if (response.statusCode == 200 || response.statusCode == 201) {
// //             ScaffoldMessenger.of(context).showSnackBar(
// //               const SnackBar(content: Text('Task saved successfully')),
// //             );
// //             Navigator.pop(context, true);
// //           } else {
// //             final responseBody = response.body;
// //             print('Failed to save task: ${response.statusCode}, Response: $responseBody');
// //             ScaffoldMessenger.of(context).showSnackBar(
// //               SnackBar(content: Text('Failed to save task: $responseBody')),
// //             );
// //           }
// //         } else {
// //           // Add Task API (POST) - Creating a new task
// //           final request = http.MultipartRequest(
// //             'POST',
// //             Uri.parse('${widget.baseUrl}/api/work-tracking/ass/insert'),
// //           );

// //           request.headers['Authorization'] = 'Bearer $token';
// //           request.fields['project_id'] = widget.projectId;
// //           request.fields['status_id'] = _selectedStatus;
// //           request.fields['title'] = _titleController.text;
// //           request.fields['descriptions'] = _descriptionController.text;
// //           request.fields['memberDetails'] = taskData['memberDetails'] ?? ''; // Fix for nullable String

// //           // Attach files (if any)
// //           if (_files.isNotEmpty) {
// //             for (var file in _files) {
// //               request.files.add(
// //                 await http.MultipartFile.fromPath(
// //                   'file_name',
// //                   file.path,
// //                 ),
// //               );
// //             }
// //           }

// //           final response = await request.send();

// //           if (response.statusCode == 201) {
// //             ScaffoldMessenger.of(context).showSnackBar(
// //               const SnackBar(content: Text('Task added successfully')),
// //             );
// //             Navigator.pop(context, true);
// //           } else {
// //             final errorResponse = await response.stream.bytesToString();
// //             print('Failed to add task: StatusCode: ${response.statusCode}, Error: $errorResponse');
// //             ScaffoldMessenger.of(context).showSnackBar(
// //               SnackBar(content: Text('Failed to add task: $errorResponse')),
// //             );
// //           }
// //         }
// //       } on SocketException catch (e) {
// //         print('Network error: $e');
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Network error. Please check your internet connection.')),
// //         );
// //       } on FormatException catch (e) {
// //         print('Response format error: $e');
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Invalid response format from the server.')),
// //         );
// //       } catch (e) {
// //         print('Unexpected error: $e');
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text('Unexpected error: $e')),
// //         );
// //       }
// //     }
// //   }

// //   void _openAddPeoplePage() async {
// //     final selectedPeople = await Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (context) => AddPeoplePageWorkTracking(
// //           asId: widget.projectId, // Pass the asId (assignment ID)
// //           projectId: widget.projectId,
// //           onSelectedPeople: (people) {
// //             setState(() {
// //               _selectedPeople = people; // Capture selected people
// //             });
// //           },
// //         ),
// //       ),
// //     );

// //     if (selectedPeople != null) {
// //       setState(() {
// //         _selectedPeople = selectedPeople;
// //       });
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     Provider.of<ThemeNotifier>(context);

// //     return AlertDialog(
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
// //       title: Text(widget.isEdit ? 'Edit Task' : 'Add Task'),  // Differentiating between Add and Edit
// //       content: SingleChildScrollView(
// //         child: Form(
// //           key: _formKey,
// //           child: Column(
// //             children: [
// //               // Title Field
// //               TextFormField(
// //                 controller: _titleController,
// //                 decoration: const InputDecoration(labelText: 'Title'),
// //                 validator: (value) {
// //                   if (value == null || value.isEmpty) {
// //                     return 'Please enter a title';
// //                   }
// //                   return null;
// //                 },
// //               ),
// //               const SizedBox(height: 10),

// //               // Status Dropdown
// //               DropdownButtonFormField<String>(
// //                 value: _TaskModal.statusOptions.any((status) => status['id'] == _selectedStatus) ? _selectedStatus : null,
// //                 decoration: const InputDecoration(labelText: 'Status'),
// //                 icon: const Icon(Icons.arrow_downward),
// //                 iconSize: 24,
// //                 elevation: 16,
// //                 style: const TextStyle(color: Colors.black),
// //                 onChanged: (String? newValue) {
// //                   setState(() {
// //                     _selectedStatus = newValue!;
// //                   });
// //                 },
// //                 items: _TaskModal.statusOptions.map<DropdownMenuItem<String>>((status) {
// //                   return DropdownMenuItem<String>(
// //                     value: status['id'],
// //                     child: Row(
// //                       children: [
// //                         Icon(Icons.circle, color: _getStatusColor(status['name']), size: 12),
// //                         const SizedBox(width: 8),
// //                         Text(status['name']),
// //                       ],
// //                     ),
// //                   );
// //                 }).toList(),
// //               ),
// //               const SizedBox(height: 10),

// //               // Description Field
// //               TextFormField(
// //                 controller: _descriptionController,
// //                 decoration: const InputDecoration(labelText: 'Description'),
// //                 maxLines: 3,
// //               ),
// //               const SizedBox(height: 10),

// //               // Only show additional fields for Add Task
// //               // if (!widget.isEdit) ...[
// //               //   // Start Date Field (Only for Add)
// //               //   GestureDetector(
// //               //     onTap: () => _selectStartDate(context),
// //               //     child: AbsorbPointer(
// //               //       child: TextFormField(
// //               //         controller: _startDateController,
// //               //         decoration: const InputDecoration(
// //               //           labelText: 'Start Date',
// //               //           suffixIcon: Icon(Icons.calendar_today),
// //               //         ),
// //               //         validator: (value) {
// //               //           if (value == null || value.isEmpty) {
// //               //             return 'Please select a start date';
// //               //           }
// //               //           return null;
// //               //         },
// //               //       ),
// //               //     ),
// //               //   ),
// //               //   const SizedBox(height: 10),
// //               //
// //               //   // Due Date Field (Only for Add)
// //               //   GestureDetector(
// //               //     onTap: () => _selectDueDate(context),
// //               //     child: AbsorbPointer(
// //               //       child: TextFormField(
// //               //         controller: _dueDateController,
// //               //         decoration: const InputDecoration(
// //               //           labelText: 'End Date',
// //               //           suffixIcon: Icon(Icons.calendar_today),
// //               //         ),
// //               //         validator: (value) {
// //               //           if (value == null || value.isEmpty) {
// //               //             return 'Please select an end date';
// //               //           }
// //               //           return null;
// //               //         },
// //               //       ),
// //               //     ),
// //               //   ),
// //               //   const SizedBox(height: 10),

// //               // File Upload Button (Only for Add)
// //               ElevatedButton.icon(
// //                 onPressed: _pickFile,
// //                 icon: const Icon(Icons.attach_file),
// //                 label: const Text('Upload File'),
// //                 style: ElevatedButton.styleFrom(
// //                   foregroundColor: Colors.white,
// //                   backgroundColor: Colors.green,
// //                 ),
// //               ),
// //               const SizedBox(height: 10),

// //               // Display Selected Files (Using Wrap)
// //               Wrap(
// //                 spacing: 8.0,
// //                 children: _files.map((file) {
// //                   return Chip(
// //                     label: Text(file.path.split('/').last),
// //                     deleteIcon: const Icon(Icons.cancel, color: Colors.red), // 'X' button
// //                     onDeleted: () => _removeFile(file), // Remove file on delete button click
// //                   );
// //                 }).toList(),
// //               ),
// //               const SizedBox(height: 10),

// //               // Add Members Button (Only for Add)
// //                 ElevatedButton.icon(
// //                   onPressed: _openAddPeoplePage,
// //                   icon: const Icon(Icons.person_add),
// //                   label: const Text('Add Members'),
// //                   style: ElevatedButton.styleFrom(
// //                     foregroundColor: Colors.white,
// //                     backgroundColor: Colors.blue,
// //                   ),
// //                 ),
// //                 const SizedBox(height: 10),

// //                 // Display Selected Members (Only for Add)
// //                 Wrap(
// //                   spacing: 8.0,
// //                   runSpacing: 8.0,
// //                   children: _selectedPeople.map((person) {
// //                     return Column(
// //                       mainAxisSize: MainAxisSize.min,
// //                       children: [
// //                         GestureDetector(
// //                           onTap: () {
// //                             // Handle tap on avatar function, if needed
// //                           },
// //                           child: CircleAvatar(
// //                             radius: 30,
// //                             backgroundImage: person['profile_image'] != null && person['profile_image'].isNotEmpty
// //                                 ? NetworkImage(person['profile_image'])
// //                                 : const AssetImage('assets/default_avatar.png') as ImageProvider,
// //                           ),
// //                         ),
// //                         const SizedBox(height: 5),
// //                         Text(
// //                           person['name'] ?? 'No Name',
// //                           style: const TextStyle(fontSize: 12),
// //                         ),
// //                       ],
// //                     );
// //                   }).toList(),
// //                 ),
// //               ],
// //           ),
// //         ),
// //       ),
// //       actions: [
// //         TextButton(
// //           onPressed: () {
// //             Navigator.pop(context);
// //           },
// //           child: const Text('Cancel'),
// //         ),
// //         ElevatedButton(
// //           onPressed: _saveTask,
// //           style: ElevatedButton.styleFrom(
// //             foregroundColor: Colors.black,
// //             backgroundColor: Colors.amber,
// //           ),
// //           child: const Text('Add'),
// //         ),
// //       ],
// //     );
// //   }

// //   Color _getStatusColor(String statusName) {
// //     switch (statusName) {
// //       case 'Pending':
// //         return Colors.orange;
// //       case 'Processing':
// //         return Colors.blue;
// //       case 'Finished':
// //         return Colors.green;
// //       default:
// //         return Colors.black;
// //     }
// //   }
// // }

// // class AddPeoplePageWorkTracking extends StatefulWidget {
// //   final String asId;
// //   final String projectId;
// //   final Function(List<Map<String, dynamic>>) onSelectedPeople;

// //   const AddPeoplePageWorkTracking({
// //     super.key,
// //     required this.asId,
// //     required this.projectId,
// //     required this.onSelectedPeople,
// //   });

// //   @override
// //   _AddPeoplePageWorkTrackingState createState() => _AddPeoplePageWorkTrackingState();
// // }

// // class _AddPeoplePageWorkTrackingState extends State<AddPeoplePageWorkTracking> {
// //   List<Map<String, dynamic>> _members = [];
// //   final List<Map<String, dynamic>> _selectedPeople = [];
// //   String _searchQuery = '';
// //   bool _isLoading = true;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _fetchProjectMembers(); // Fetch available members for the project
// //   }

// //   Future<void> _fetchProjectMembers() async {
// //     setState(() {
// //       _isLoading = true; // Set loading state
// //     });

// //     try {
// //       final prefs = await SharedPreferences.getInstance();
// //       final token = prefs.getString('token'); // Fetch the token from storage

// //       if (token == null) {
// //         throw Exception('No token found. Please log in again.');
// //       }

// //       // Fetch project members from the backend
// //       final url = Uri.parse(
// //           'https://demo-application-api.flexiflows.co/api/work-tracking/project-member/members?project_id=${widget.projectId}');
// //       final response = await http.get(url, headers: {
// //         'Authorization': 'Bearer $token', // Pass the token in the headers
// //       });

// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //         final List<dynamic> membersList = data['results'];

// //         // Filter and prepare the list of members
// //         setState(() {
// //           _members = membersList.map<Map<String, dynamic>>((member) {
// //             return {
// //               'name': member['name'] ?? 'No Name',
// //               'surname': member['surname'] ?? '',
// //               'email': member['email'] ?? 'Unknown Email',
// //               'employee_id': member['employee_id'],
// //               'isSelected': false, // Track selection
// //             };
// //           }).toList();
// //         });
// //       } else {
// //         throw Exception('Failed to load project members');
// //       }
// //     } catch (e) {
// //       print('Error fetching project members: $e');
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Error fetching project members: $e')),
// //       );
// //     } finally {
// //       setState(() {
// //         _isLoading = false; // Loading is done
// //       });
// //     }
// //   }

// //   Future<void> _fetchProfileImages() async {
// //     try {
// //       final prefs = await SharedPreferences.getInstance();
// //       final token = prefs.getString('token'); // Fetch the token from storage

// //       if (token == null) {
// //         throw Exception('No token found. Please log in again.');
// //       }

// //       // Fetch profile images for each member
// //       for (var member in _members) {
// //         final employeeId = member['employee_id'];
// //         final response = await http.get(
// //           Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
// //           headers: {
// //             'Authorization': 'Bearer $token', // Include the token in the request headers
// //           },
// //         );

// //         if (response.statusCode == 200) {
// //           final profileData = jsonDecode(response.body);
// //           setState(() {
// //             member['images'] = profileData['images'] ?? ''; // Update the image URL
// //           });
// //         } else {
// //           print('Failed to load profile image for $employeeId: ${response.body}');
// //         }
// //       }
// //     } catch (e) {
// //       print('Error fetching profile images: $e');
// //     }
// //   }

// //   void _toggleSelection(int index) {
// //     setState(() {
// //       _members[index]['isSelected'] = !_members[index]['isSelected'];
// //     });
// //   }

// //   void _onAddMembersPressed() {
// //     final selectedMembers = _members.where((member) => member['isSelected']).toList();
// //     if (selectedMembers.isNotEmpty) {
// //       widget.onSelectedPeople(selectedMembers); // Return selected members
// //       Navigator.pop(context);
// //     } else {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text('Please select at least one member')),
// //       );
// //     }
// //   }

// //   Future<void> _confirmSelection() async {
// //     final selectedMembers = _members.where((member) => member['isSelected']).toList();

// //     // Map the selected members' employee_id to be sent to the backend
// //     final List<Map<String, dynamic>> memberDetails = selectedMembers
// //         .map<Map<String, dynamic>>((member) => {'employee_id': member['employee_id']})
// //         .toList();

// //     try {
// //       final prefs = await SharedPreferences.getInstance();
// //       final token = prefs.getString('token'); // Fetch token for authenticated requests

// //       if (token == null) {
// //         throw Exception('No token found');
// //       }

// //       final url = Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/assignment-members/insert');
// //       final response = await http.post(
// //         url,
// //         headers: {
// //           'Authorization': 'Bearer $token',
// //           'Content-Type': 'application/json',
// //         },
// //         body: jsonEncode({
// //           'assignment_id': widget.asId, // Pass the assignment ID
// //           'memberDetails': memberDetails, // Pass the selected members
// //         }),
// //       );

// //       if (response.statusCode == 200 || response.statusCode == 201) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Members added successfully!')),
// //         );
// //         Navigator.pop(context, true); // Close modal and return success
// //       } else {
// //         throw Exception('Failed to add members');
// //       }
// //     } catch (e) {
// //       print('Error adding members: $e');
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Error adding members: $e')),
// //       );
// //     }
// //   }

// //   void _showMemberDetails(String employeeName) {
// //     showDialog(
// //       context: context,
// //       builder: (context) => AlertDialog(
// //         title: const Text('Member Details'),
// //         content: Text('Employee Name: $employeeName'),
// //         actions: [
// //           TextButton(
// //             onPressed: () {
// //               Navigator.of(context).pop();
// //             },
// //             child: const Text('Close'),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     // Filter members based on the search query
// //     final filteredMembers = _members.where((member) {
// //       final memberName = member['name']?.toLowerCase() ?? '';
// //       return memberName.contains(_searchQuery.toLowerCase());
// //     }).toList();

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text(
// //           'Add People',
// //           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
// //         ),
// //         flexibleSpace: ClipPath(
// //           clipper: CustomAppBarClipper(),
// //           child: Container(
// //             decoration: const BoxDecoration(
// //               image: DecorationImage(
// //                 image: AssetImage('assets/background.png'),
// //                 fit: BoxFit.cover,
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //       body: _isLoading
// //           ? const Center(child: CircularProgressIndicator()) // Show loading indicator when loading
// //           : Column(
// //         children: [
// //           // Search bar
// //           Padding(
// //             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
// //             child: TextField(
// //               onChanged: (value) {
// //                 setState(() {
// //                   _searchQuery = value;
// //                 });
// //               },
// //               decoration: InputDecoration(
// //                 prefixIcon: const Icon(Icons.search),
// //                 hintText: 'Search',
// //                 border: OutlineInputBorder(
// //                   borderRadius: BorderRadius.circular(30.0),
// //                 ),
// //               ),
// //             ),
// //           ),
// //           // Member list
// //           Expanded(
// //             child: ListView.builder(
// //               itemCount: filteredMembers.length,
// //               itemBuilder: (context, index) {
// //                 final member = filteredMembers[index];
// //                 final imageUrl = member['image'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

// //                 return Card(
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(10.0),
// //                   ),
// //                   child: ListTile(
// //                     leading: GestureDetector(
// //                       onTap: () => _showMemberDetails(member['name']), // Show member details on tap
// //                       child: CircleAvatar(
// //                         backgroundImage: NetworkImage(imageUrl),
// //                         onBackgroundImageError: (exception, stackTrace) {
// //                           if (kDebugMode) {
// //                             print('Error loading image for employee ${member['employee_id']}: $exception');
// //                           }
// //                         },
// //                       ),
// //                     ),
// //                     title: Text(member['name'] ?? 'No Name'),
// //                     subtitle: Text('${member['surname']} - ${member['email']}'),
// //                     trailing: Checkbox(
// //                       value: member['isSelected'], // Checkbox for selecting the member
// //                       onChanged: (bool? value) {
// //                         _toggleSelection(index); // Toggle selection on checkbox change
// //                       },
// //                     ),
// //                   ),
// //                 );
// //               },
// //             ),
// //           ),
// //           // Button to confirm selected members
// //           Padding(
// //             padding: const EdgeInsets.all(16.0),
// //             child: ElevatedButton.icon(
// //               onPressed: () {
// //                 _onAddMembersPressed(); // Confirm selected members
// //                 _confirmSelection(); // Confirm and save the selected members
// //               },
// //               icon: const Icon(Icons.add),
// //               label: const Text('Add Members'),
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.amber,
// //                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
// //                 shape: RoundedRectangleBorder(
// //                   borderRadius: BorderRadius.circular(30.0),
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // class PdfViewer extends StatelessWidget {
// //   final String filePath;

// //   const PdfViewer({super.key, required this.filePath});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text('PDF Viewer'),
// //       ),
// //       body: PDFView(
// //         filePath: filePath,
// //       ),
// //     );
// //   }
// // }

// import 'dart:convert';
// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:http/http.dart' as http;
// import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/backup_project_management_page.dart';
// import 'package:pb_hrsystem/services/assignment_service.dart';
// import 'package:pb_hrsystem/services/image_viewer.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:pb_hrsystem/services/work_tracking_service.dart';
// import 'package:pb_hrsystem/theme/theme.dart';
// import 'package:flutter_pdfview/flutter_pdfview.dart';

// class ProjectManagementPage extends StatefulWidget {
//   final String projectId;
//   final String baseUrl;

//   const ProjectManagementPage({super.key, required this.projectId, required this.baseUrl});

//   @override
//   _ProjectManagementPageState createState() => _ProjectManagementPageState();
// }

// class _ProjectManagementPageState extends State<ProjectManagementPage> with SingleTickerProviderStateMixin {
//   List<Map<String, dynamic>> _tasks = [];
//   List<Map<String, dynamic>> _messages = [];
//   String _selectedStatus = 'All Status';
//   final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Finished'];
//   late TabController _tabController;
//   final TextEditingController _messageController = TextEditingController();
//   String _currentUserId = '';
//   final WorkTrackingService _workTrackingService = WorkTrackingService();
//   final AssignmentService _assignmentService = AssignmentService();
//   final ScrollController _scrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _loadUserData();
//     _fetchProjectData();
//     _loadChatMessages();
//     _loadCurrentUser();
//   }

// // Method to delete a member from a task
// Future<void> _deleteMember(String memberId, int taskIndex) async {
//   final prefs = await SharedPreferences.getInstance();
//   final token = prefs.getString('token');

//   if (token == null) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Token is null. Please log in again.')),
//     );
//     return;
//   }

//   final url = Uri.parse('${widget.baseUrl}/api/work-tracking/assignment-members/delete/$memberId');

//   final response = await http.put(
//     url,
//     headers: {
//       'Authorization': 'Bearer $token',
//       'Content-Type': 'application/json',
//     },
//   );

//   if (response.statusCode == 200) {
//     setState(() {
//       _tasks[taskIndex]['members'].removeWhere((member) => member['id'] == memberId);
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Member deleted successfully')),
//     );
//   } else {
//     final responseData = jsonDecode(response.body);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Failed to delete member: ${responseData['error'] ?? 'Unknown error'}')),
//     );
//   }
// }

//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _currentUserId = prefs.getString('userId') ?? '';
//     });
//   }

//   Future<void> _fetchProjectData() async {
//     try {
//       final tasks = await _workTrackingService.fetchAssignments(widget.projectId);
//       setState(() {
//         _tasks = tasks.where((task) => task['proj_id'] == widget.projectId).map((task) {
//           return {
//             'id': task['id'],
//             'as_id': task['as_id'], 
//             'title': task['title'] ?? 'No Title',
//             'status': task['s_name'] ?? 'Unknown',
//             'start_date': task['created_at']?.substring(0, 10) ?? 'N/A',
//             'due_date': task['updated_at']?.substring(0, 10) ?? 'N/A',
//             'description': task['description'] ?? 'No Description',
//             'files': task['file_name'] != null ? task['file_name'].split(',') : [],
//             'members': task['members'] ?? [],
//           };
//         }).toList();
//       });
//     } catch (e) {
//       if (kDebugMode) {
//         print('Failed to load project data: $e');
//       }
//     }
//   }

//   void _showAddTaskModal() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return _TaskModal(
//           onSave: (newTask) async {
//             _addTask(newTask);
//           },
//           isEdit: false,
//           projectId: widget.projectId,
//           baseUrl: widget.baseUrl,
//         );
//       },
//     ).then((value) {
//       if (value == true) {
//         _refreshWholePage(); // Full page refresh
//       }
//     });
//   }


//   void _refreshWholePage() {
//     setState(() {
//       _fetchProjectData();
//       _tabController = TabController(length: 2, vsync: this);
//     });
//   }

//   void _showEditTaskModal(Map<String, dynamic> task, int index) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return _TaskModal(
//           task: task,
//           onSave: (updatedTask) async {
//             _editTask(index, updatedTask);
//           },
//           isEdit: true,
//           projectId: widget.projectId,
//           baseUrl: widget.baseUrl,
//         );
//       },
//     ).then((value) {
//       if (value == true) {
//         _refreshWholePage(); // Full page refresh
//       }
//     });
//   }

//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.jumpTo(_scrollController.position.minScrollExtent); // Jump to the bottom
//       }
//     });
//   }

//   Future<void> _loadChatMessages() async {
//     try {
//       final messages = await _workTrackingService.fetchChatMessages(widget.projectId);
//       setState(() {
//         _messages = messages.map((message) {
//           return {
//             ...message,
//             'createBy_name': message['created_by'] == _currentUserId ? 'You' : message['createBy_name'],
//           };
//         }).toList();
//       });
//       _scrollToBottom(); // Ensure scrolling to the bottom after messages are loaded
//     } catch (e) {
//       if (kDebugMode) {
//         print('Failed to load chat messages: $e');
//       }
//     }
//   }

//   Widget _buildChatAndConversationTab(bool isDarkMode) {
//     return Column(
//       children: [
//         Expanded(
//           child: ListView.builder(
//             reverse: true, // Reverse the order of the list to show the latest message at the bottom
//             controller: _scrollController,
//             padding: const EdgeInsets.all(16.0),
//             itemCount: _messages.length,
//             itemBuilder: (context, index) {
//               final message = _messages[index];
//               final nextMessage = index + 1 < _messages.length ? _messages[index + 1] : null;

//               // Check if the date of the current message is different from the next one (since list is reversed)
//               final bool isNewDate = nextMessage == null ||
//                   _formatDate(message['created_at']) != _formatDate(nextMessage['created_at']);

//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   if (isNewDate) // Display date header
//                     Center(
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 8.0),
//                         child: Text(
//                           _formatDate(message['created_at']),
//                           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
//                         ),
//                       ),
//                     ),
//                   _buildChatMessage(message, nextMessage, isDarkMode), // Message bubble
//                 ],
//               );
//             },
//           ),
//         ),
//         _buildChatInput(isDarkMode), // Chat input at the bottom
//       ],
//     );
//   }

//   String _formatDate(String timestamp) {
//     final DateTime messageDate = DateTime.parse(timestamp);
//     final DateTime now = DateTime.now();

//     if (messageDate.year == now.year && messageDate.month == now.month && messageDate.day == now.day) {
//       return 'Today';
//     } else if (messageDate.year == now.year && messageDate.month == now.month && messageDate.day == now.day - 1) {
//       return 'Yesterday';
//     } else {
//       return DateFormat('dd MMM yyyy').format(messageDate);
//     }
//   }

//   String _formatTimestamp(String timestamp) {
//     final DateTime messageTime = DateTime.parse(timestamp);
//     return DateFormat('hh:mm a').format(messageTime); // Time in hh:mm AM/PM format
//   }

//   Widget _buildChatMessage(Map<String, dynamic> message, Map<String, dynamic>? nextMessage, bool isDarkMode) {
//     final bool isSentByMe = message['created_by'] == _currentUserId;
//     final String senderName = isSentByMe ? 'You' : message['createBy_name'] ?? 'Unknown'; // Replace current user name with 'You'

//     final Color messageColor = isSentByMe
//         ? Colors.blue.shade200 // Your own messages (light blue)
//         : _assignChatBubbleColor(message['created_by']); // Different color for others

//     final Color textColor = isDarkMode ? Colors.white : Colors.black;
//     final Alignment messageAlignment = isSentByMe ? Alignment.centerRight : Alignment.centerLeft;

//     return GestureDetector(
//       onTap: () {
//         if (isSentByMe) {
//           _showDeleteConfirmation(message['comment_id']); // Only allow deletion of own messages
//         }
//       },
//       child: Align(
//         alignment: messageAlignment,
//         child: Container(
//           margin: const EdgeInsets.symmetric(vertical: 8.0),
//           padding: const EdgeInsets.all(12.0),
//           decoration: BoxDecoration(
//             color: messageColor,
//             borderRadius: BorderRadius.only(
//               topLeft: isSentByMe ? const Radius.circular(12.0) : const Radius.circular(0),
//               topRight: isSentByMe ? const Radius.circular(0) : const Radius.circular(12.0),
//               bottomLeft: const Radius.circular(12.0),
//               bottomRight: const Radius.circular(12.0),
//             ),
//           ),
//           child: Column(
//             crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//             children: [
//               if (!isSentByMe) // Only show name for others' messages
//                 Text(
//                   senderName,
//                   style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold),
//                 ),
//               const SizedBox(height: 4),
//               Text(
//                 message['comments'] ?? '',
//                 style: TextStyle(color: textColor, fontSize: 16),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 _formatTimestamp(message['created_at']),
//                 style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Color _assignChatBubbleColor(String userId) {
//     final List<Color> colors = [
//       Colors.green.shade100,
//       Colors.orange.shade100,
//       Colors.purple.shade100,
//       Colors.red.shade100,
//       Colors.yellow.shade100,
//     ];

//     final int hashValue = userId.hashCode % colors.length;
//     return colors[hashValue];
//   }

//   Widget _buildChatInput(bool isDarkMode) {
//     final Color backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
//     final Color textColor = isDarkMode ? Colors.white : Colors.black;
//     final Color sendButtonColor = isDarkMode ? Colors.green[300]! : Colors.green;

//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
//         decoration: BoxDecoration(
//           color: backgroundColor,
//           borderRadius: BorderRadius.circular(30.0),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               spreadRadius: 1,
//               blurRadius: 8,
//               offset: const Offset(2, 4),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: TextField(
//                 controller: _messageController,
//                 decoration: InputDecoration(
//                   hintText: 'Type a message...',
//                   hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
//                   border: InputBorder.none,
//                 ),
//                 style: TextStyle(color: textColor),
//                 maxLines: null,
//               ),
//             ),
//             const SizedBox(width: 8),
//             CircleAvatar(
//               radius: 25,
//               backgroundColor: sendButtonColor,
//               child: IconButton(
//                 icon: const Icon(Icons.send, color: Colors.white),
//                 onPressed: () {
//                   if (_messageController.text.isNotEmpty) {
//                     _sendMessage(_messageController.text);
//                   }
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _currentUserName = '';

//   Future<void> _loadCurrentUser() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token');

//     if (token == null) {
//       // Handle token missing case
//       return;
//     }

//     final response = await http.get(
//       Uri.parse('${widget.baseUrl}/api/display/me'),
//       headers: {
//         'Authorization': 'Bearer $token',
//       },
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       if (data['results'] != null && data['results'].isNotEmpty) {
//         setState(() {
//           _currentUserId = data['results'][0]['id'];  // Set current user ID
//           _currentUserName = data['results'][0]['employee_name']; // Set current user name
//         });
//       }
//     }
//   }

//   Future<void> _sendMessage(String message) async {
//     try {
//       await _workTrackingService.sendChatMessage(widget.projectId, message);
//       _addMessage(message);
//     } catch (e) {
//       if (kDebugMode) {
//         print('Failed to send message: $e');
//       }
//     }
//   }

//   void _showDeleteConfirmation(String commentId) {
//     print('Comment ID to delete: $commentId');  // For debugging

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Delete Message'),
//           content: const Text('Would you like to delete this message?'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close the modal
//               },
//               child: const Text('No'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close the modal
//                 _deleteMessage(commentId); // Delete the message
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//               ),
//               child: const Text('Yes'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _addMessage(String message) {
//     final DateTime now = DateTime.now();
//     setState(() {
//       _messages.insert(0, {
//         'comments': message,
//         'created_at': now.toIso8601String(),
//         'createBy_name': 'You',
//         'created_by': _currentUserId,
//       });
//     });
//     _messageController.clear();
//     _scrollToBottom();
//   }

//   @override
//   void dispose() {
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final themeNotifier = Provider.of<ThemeNotifier>(context);
//     final bool isDarkMode = themeNotifier.isDarkMode;

//     List<Map<String, dynamic>> filteredTasks = _tasks.where((task) => _selectedStatus == 'All Status' || task['status'] == _selectedStatus).toList();
//     List<File> selectedFiles = [];

//     return Scaffold(
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(85.0),
//         child: AppBar(
//           automaticallyImplyLeading: true,
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           flexibleSpace: ClipRRect(
//             borderRadius: const BorderRadius.only(
//               bottomLeft: Radius.circular(20),
//               bottomRight: Radius.circular(20),
//             ),
//             child: Container(
//               decoration: const BoxDecoration(
//                 image: DecorationImage(
//                   image: AssetImage('assets/background.png'),
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//           ),

//           leading: Padding(
//             padding: const EdgeInsets.only(top: 25.0),
//             child: IconButton(
//               icon: const Icon(Icons.arrow_back, color: Colors.black),
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//             ),
//           ),

//           title: const Padding(
//             padding: EdgeInsets.only(top: 34.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.start,
//               children: [
//                 Spacer(flex: 2),
//                 Text(
//                   'Work Tracking',
//                   style: TextStyle(
//                     color: Colors.black,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 24,
//                   ),
//                 ),
//                 Spacer(flex: 4),
//               ],
//             ),
//           ),
//         ),
//       ),

//       body: Column(
//         children: [
//           TabBar(
//             controller: _tabController,
//             labelColor: Colors.amber,
//             unselectedLabelColor: Colors.grey,
//             indicatorColor: Colors.amber,
//             labelStyle: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//             unselectedLabelStyle: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.normal,
//             ),
//             tabs: const [
//               Tab(text: 'Assignment / Task'),
//               Tab(text: 'Comment / Chat'),
//             ],
//           ),
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 _buildProcessingOrDetailTab(filteredTasks),
//                 _buildChatAndConversationTab(isDarkMode),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildProcessingOrDetailTab(List<Map<String, dynamic>> filteredTasks) {
//     final themeNotifier = Provider.of<ThemeNotifier>(context);
//     final bool isDarkMode = themeNotifier.isDarkMode;

//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Row(
//             children: [
//               Expanded(
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 300),
//                   curve: Curves.easeInOut,
//                   decoration: BoxDecoration(
//                     gradient: isDarkMode
//                         ? const LinearGradient(
//                       colors: [Color(0xFF424242), Color(0xFF303030)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     )
//                         : const LinearGradient(
//                       colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.1),
//                         blurRadius: 10,
//                         spreadRadius: 1,
//                         offset: const Offset(1, 1),
//                       ),
//                     ],
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),

//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: DropdownButtonHideUnderline(
//                     child: DropdownButton<String>(
//                       value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
//                       icon: const Icon(Icons.arrow_downward, color: Colors.amber),
//                       iconSize: 28,
//                       elevation: 16,
//                       dropdownColor: isDarkMode ? const Color(0xFF424242) : Colors.white,
//                       style: TextStyle(
//                         color: isDarkMode ? Colors.white : Colors.black87,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                       onChanged: (String? newValue) {
//                         setState(() {
//                           _selectedStatus = newValue!;
//                         });
//                       },
//                       items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
//                         return DropdownMenuItem<String>(
//                           value: value,
//                           child: Row(
//                             children: [
//                               Icon(Icons.circle, color: _getStatusColor(value), size: 14),
//                               const SizedBox(width: 10),
//                               Text(value),
//                             ],
//                           ),
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               IconButton(
//                 icon: Container(
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: const LinearGradient(
//                       colors: [Colors.greenAccent, Colors.teal],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.2),
//                         blurRadius: 10,
//                         spreadRadius: 1,
//                         offset: const Offset(2, 4),
//                       ),
//                     ],
//                   ),
//                   padding: const EdgeInsets.all(10.0),
//                   child: const Icon(
//                     Icons.add,
//                     color: Colors.white,
//                     size: 20.0,
//                   ),
//                 ),
//                 onPressed: () => _showAddTaskModal(),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: RefreshIndicator(
//             onRefresh: _fetchProjectData,
//             child: ListView.builder(
//               padding: const EdgeInsets.all(12.0),
//               itemCount: filteredTasks.length,
//               itemBuilder: (context, index) {
//                 return GestureDetector(
//                   onTap: () {
//                     _showTaskViewModal(filteredTasks[index], index);
//                   },
//                   child: _buildTaskCard(filteredTasks[index], index),
//                 );
//               },
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTaskCard(Map<String, dynamic> task, int index) {
//     final progressColors = {
//       'Pending': Colors.orange,
//       'Processing': Colors.blue,
//       'Finished': Colors.green,
//     };

//     final startDate = DateTime.parse(task['start_date'] ?? DateTime.now().toIso8601String());
//     final dueDate = DateTime.parse(task['due_date'] ?? DateTime.now().toIso8601String());
//     final daysRemaining = dueDate.difference(startDate).inDays;

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 10.0),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [
//             Color(0xFFE0E0F0),
//             Color(0xFFF7F7FF),
//             Color(0xFFFFFFFF),
//           ],
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 8,
//             spreadRadius: 1,
//             offset: const Offset(4, 4),
//           ),
//         ],
//         borderRadius: BorderRadius.circular(16.0),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   Icons.circle,
//                   color: progressColors[task['status']] ?? Colors.black,
//                   size: 14,
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   task['status'] ?? 'Unknown',
//                   style: TextStyle(
//                     color: progressColors[task['status']] ?? Colors.black,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 const Spacer(),
//                 const Icon(
//                   Icons.more_vert,
//                   color: Colors.black54,
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Text(
//               task['title'] ?? 'No Title',
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildIconTextRow(
//                   icon: Icons.calendar_today,
//                   label: 'Start Date: ${task['start_date'] ?? 'N/A'}',
//                   iconColor: Colors.orangeAccent,
//                 ),
//                 const SizedBox(height: 8),
//                 _buildIconTextRow(
//                   icon: Icons.calendar_today_outlined,
//                   label: 'Due Date: ${task['due_date'] ?? 'N/A'}',
//                   iconColor: Colors.redAccent,
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             _buildIconTextRow(
//               icon: Icons.timelapse,
//               label: 'Days Remaining: $daysRemaining',
//               iconColor: Colors.greenAccent,
//             ),
//             const SizedBox(height: 12),
//             Text(
//               task['description'] ?? 'No Description',
//               style: const TextStyle(
//                 color: Colors.black54,
//                 fontSize: 14,
//                 height: 1.5,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildIconTextRow({required IconData icon, required String label, Color? iconColor}) {
//     return Row(
//       children: [
//         Icon(icon, color: iconColor ?? Colors.black54, size: 18), 
//         const SizedBox(width: 8),
//         Expanded(
//           child: Text(
//             label,
//             style: const TextStyle(
//               fontSize: 14,
//               color: Colors.black87,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _showTaskViewModal(Map<String, dynamic> task, int index) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//           title: const Text('View Task'),
//           content: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Title: ${task['title'] ?? 'No Title'}', style: const TextStyle(fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 10),
//                 Text('Status: ${task['status'] ?? 'Unknown'}', style: TextStyle(color: _getStatusColor(task['status'] ?? 'Unknown'))),
//                 const SizedBox(height: 10),
//                 Text('Start Date: ${task['start_date'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
//                 const SizedBox(height: 10),
//                 Text('Due Date: ${task['due_date'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
//                 const SizedBox(height: 10),
//                 Text('Description: ${task['description'] ?? 'No Description'}', style: const TextStyle(color: Colors.black87)),
//                 const SizedBox(height: 10),
//                 const Text('Attachments:'),
//                 const SizedBox(height: 10),

//                 // Attachments Section
//                 SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     children: task['files'].map<Widget>((filePath) {
//                       final fileExtension = filePath.split('.').last.toLowerCase();

//                       return GestureDetector(
//                         onTap: () {
//                           print('Opening PDF at: ${widget.baseUrl}/$filePath'); // Debugging line
//                           if (fileExtension == 'pdf') {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => PdfViewer(filePath: '${widget.baseUrl}/$filePath'),
//                               ),
//                             );
//                           } else if (['jpg', 'jpeg', 'png'].contains(fileExtension)) {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => ImageViewer(imagePath: '${widget.baseUrl}/$filePath'),
//                               ),
//                             );
//                           } else {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(content: Text('Unsupported file format')),
//                             );
//                           }
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(vertical: 8.0),
//                           child: Row(
//                             children: [
//                               Icon(fileExtension == 'pdf' ? Icons.picture_as_pdf : Icons.image),
//                               const SizedBox(width: 8),
//                               Text(filePath.split('/').last),
//                             ],
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                 ),
//                 const SizedBox(height: 20),

//                const Text('Assigned Members:'),
// const SizedBox(height: 10),
// const Text('Assigned Members:'),
// const SizedBox(height: 10),
// task['members'] != null && task['members'].isNotEmpty
//     ? Wrap(
//         spacing: 8.0,
//         children: List.generate(task['members'].length, (index) {
//           final member = task['members'][index];
//           return Stack(
//             children: [
//               Column(
//                 children: [
//                   CircleAvatar(
//                     backgroundImage: member['image'] != null && member['image'].isNotEmpty
//                         ? NetworkImage(member['image'])
//                         : const NetworkImage('https://demo-application-api.flexiflows.co/default_avatar.jpg'),
//                     radius: 24,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     member['name'] ?? 'No Name',
//                     style: const TextStyle(fontSize: 12),
//                     overflow: TextOverflow.ellipsis,
//                     maxLines: 1,
//                   ),
//                 ],
//               ),
//               Positioned(
//                 top: 0,
//                 right: 0,
//                 child: IconButton(
//                   icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
//                   onPressed: () {
//                     setState(() {
//                       task['members'].removeAt(index); // Remove the member from the list
//                     });
//                   },
//                 ),
//               ),
//             ],
//           );
//         }),
//       )
//     : const Text('No members assigned', style: TextStyle(color: Colors.grey)),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Close'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _showEditTaskModal(task, index); // Open the edit modal
//               },
//               style: ElevatedButton.styleFrom(
//                 foregroundColor: Colors.black,
//                 backgroundColor: Colors.amber,
//               ),
//               child: const Text('Edit'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _deleteMessage(String commentId) async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token');

//     if (token == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Token is null. Please log in again.')),
//       );
//       return;
//     }

//     final url = Uri.parse('${widget.baseUrl}/api/work-tracking/project-comments/delete/$commentId');

//     final response = await http.put(
//       url,
//       headers: {
//         'Authorization': 'Bearer $token',
//         'Content-Type': 'application/json',
//       },
//     );

//     if (response.statusCode == 200) {
//       setState(() {
//         _messages.removeWhere((message) => message['comment_id'] == commentId);
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Message deleted successfully')),
//       );
//     } else {
//       final responseData = jsonDecode(response.body);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to delete message: ${responseData['error'] ?? 'Unknown error'}')),
//       );
//     }
//   }

//   void _showTaskModal({Map<String, dynamic>? task, int? index, bool isEdit = false}) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return _TaskModal(
//           task: task,
//           onSave: (newTask) {
//             if (task != null && index != null) {
//               _editTask(index, newTask);
//             } else {
//               _addTask(newTask);
//             }
//           },
//           isEdit: isEdit,
//           projectId: widget.projectId,
//           baseUrl: widget.baseUrl,
//         );
//       },
//     );
//   }

//   void _editTask(int index, Map<String, dynamic> updatedTask) {
//     setState(() {
//       _tasks[index] = updatedTask;
//     });
//   }

//   Future<void> _addTask(Map<String, dynamic> taskData) async {
//     try {
//       // Step 1: Create the task (POST)
//       final asId = await _workTrackingService.addAssignment(widget.projectId, {
//         'status_id': taskData['status_id'],
//         'title': taskData['title'],
//         'descriptions': taskData['descriptions'],
//         'memberDetails': taskData['memberDetails'], // If members are part of initial task creation
//       });

//       if (asId != null) {
//         // Step 2: Upload files (PUT) - If files exist
//         if (taskData['files'] != null && taskData['files'].isNotEmpty) {
//           for (var file in taskData['files']) {
//             await _workTrackingService.addFilesToAssignment(asId, [file]);
//           }
//         }

//         // Step 3: Add members (Optional - depending on your flow)
//         if (taskData['members'] != null && taskData['members'].isNotEmpty) {
//           await _workTrackingService.addMembersToAssignment(asId, taskData['members']);
//         }

//         // After all steps are complete, show success and refresh the project data
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Task created successfully with files and members!')),
//         );

//         // Refresh the project/task list
//         _fetchProjectData();

//       } else {
//         // Handle error creating the task
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to create task')),
//         );
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error adding task: $e');
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error adding task: $e')),
//       );
//     }
//   }

//   Future<void> _addMembersToAssignment(String asId, List<Map<String, dynamic>> members) async {
//     try {
//       await _workTrackingService.addMembersToAssignment(asId, members);
//     } catch (e) {
//       if (kDebugMode) {
//         print('Failed to add members to assignment: $e');
//       }
//     }
//   }

//   Color _getStatusColor(String status) {
//     switch (status) {
//       case 'Pending':
//         return Colors.orange;
//       case 'Processing':
//         return Colors.blue;
//       case 'Finished':
//         return Colors.green;
//       default:
//         return Colors.black;
//     }
//   }
// }

// class _TaskModal extends StatefulWidget {
//   final Map<String, dynamic>? task;
//   final Function(Map<String, dynamic>) onSave;
//   final bool isEdit;
//   final String projectId;
//   final String baseUrl;

//   static const List<Map<String, dynamic>> statusOptions = [
//     {'id': '40d2ba5e-a978-47ce-bc48-caceca8668e9', 'name': 'Pending'},
//     {'id': '0a8d93f0-1c05-42b2-8e56-984a578ef077', 'name': 'Processing'},
//     {'id': 'e35569eb-75e1-4005-9232-bfb57303b8b3', 'name': 'Finished'},
//   ];

//   const _TaskModal({
//     this.task,
//     required this.onSave,
//     this.isEdit = false,
//     required this.projectId,
//     required this.baseUrl,
//   });

//   @override
//   __TaskModalState createState() => __TaskModalState();
// }

// class __TaskModalState extends State<_TaskModal> {
//   late TextEditingController _titleController;
//   late TextEditingController _descriptionController;
//   String _selectedStatus = 'Pending';
//   final ImagePicker _picker = ImagePicker();
//   final List<File> _files = [];
//   List<Map<String, dynamic>> _selectedPeople = [];
//   final _formKey = GlobalKey<FormState>();

//   final WorkTrackingService _workTrackingService = WorkTrackingService();

//   @override
//   void initState() {
//     super.initState();

//     _titleController = TextEditingController(text: widget.task?['title'] ?? '');
//     _descriptionController = TextEditingController(text: widget.task?['description'] ?? '');

//     _selectedStatus = widget.task?['status'] ?? _TaskModal.statusOptions.first['id'];

//     if (widget.isEdit) {
//       _fetchAssignmentMembers();
//     }
//   }

//   Future<void> _fetchAssignmentMembers() async {
//     try {
//       final members = await _workTrackingService.fetchAssignmentMembers(widget.projectId);
//       setState(() {
//         _selectedPeople = members;
//       });
//     } catch (e) {
//       if (kDebugMode) {
//         print('Failed to load assignment members: $e');
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _descriptionController.dispose();
//     super.dispose();
//   }

//   Future<void> _pickFile() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       allowMultiple: true,
//       type: FileType.custom,
//       allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'mp4'],
//     );

//     // If the user picks a file, add it to the _files list
//     if (result != null) {
//       setState(() {
//         _files.addAll(result.paths.map((path) => File(path!)).toList());
//       });
//     } else {
//       // If no file is selected, show a message
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No file selected')),
//       );
//     }
//   }

// // Function to remove a file from the _files list
//   void _removeFile(File file) {
//     setState(() {
//       _files.remove(file);
//     });
//   }

//   Future<void> _saveTask() async {
//     if (_formKey.currentState!.validate()) {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('token');

//       if (token == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Token is null. Please log in again.')),
//         );
//         return;
//       }

//       // Prepare task data for both adding and editing
//       final taskData = {
//         'status_id': _selectedStatus,
//         'title': _titleController.text,
//         'descriptions': _descriptionController.text,
//         'memberDetails': jsonEncode([
//           {'employee_id': '12345', 'role': 'Manager'}, // Example memberDetails structure
//           {'employee_id': '67890', 'role': 'Developer'}
//         ]),
//       };

//       try {
//         // Check if it's an edit action
//         if (widget.isEdit && widget.task != null) {
//           // Edit Task API (PUT)
//           final response = await http.put(
//             Uri.parse('${widget.baseUrl}/api/work-tracking/ass/update/${widget.task!['as_id']}'),
//             headers: {
//               'Authorization': 'Bearer $token',
//               'Content-Type': 'application/json',
//             },
//             body: jsonEncode(taskData),
//           );

//           if (response.statusCode == 200 || response.statusCode == 201) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Task saved successfully')),
//             );
//             Navigator.pop(context, true);
//           } else {
//             final responseBody = response.body;
//             print('Failed to save task: ${response.statusCode}, Response: $responseBody');
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Failed to save task: $responseBody')),
//             );
//           }
//         } else {
//           // Add Task API (POST) - Creating a new task
//           final request = http.MultipartRequest(
//             'POST',
//             Uri.parse('${widget.baseUrl}/api/work-tracking/ass/insert'),
//           );

//           request.headers['Authorization'] = 'Bearer $token';
//           request.fields['project_id'] = widget.projectId;
//           request.fields['status_id'] = _selectedStatus;
//           request.fields['title'] = _titleController.text;
//           request.fields['descriptions'] = _descriptionController.text;
//           request.fields['memberDetails'] = taskData['memberDetails'] ?? ''; // Fix for nullable String

//           // Attach files (if any)
//           if (_files.isNotEmpty) {
//             for (var file in _files) {
//               request.files.add(
//                 await http.MultipartFile.fromPath(
//                   'file_name',
//                   file.path,
//                 ),
//               );
//             }
//           }

//           final response = await request.send();

//           if (response.statusCode == 201) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Task added successfully')),
//             );
//             Navigator.pop(context, true);
//           } else {
//             final errorResponse = await response.stream.bytesToString();
//             print('Failed to add task: StatusCode: ${response.statusCode}, Error: $errorResponse');
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Failed to add task: $errorResponse')),
//             );
//           }
//         }
//       } on SocketException catch (e) {
//         print('Network error: $e');
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Network error. Please check your internet connection.')),
//         );
//       } on FormatException catch (e) {
//         print('Response format error: $e');
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Invalid response format from the server.')),
//         );
//       } catch (e) {
//         print('Unexpected error: $e');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Unexpected error: $e')),
//         );
//       }
//     }
//   }

//   void _openAddPeoplePage() async {
//     final selectedPeople = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => AddPeoplePageWorkTracking(
//           asId: widget.projectId, // Pass the asId (assignment ID)
//           projectId: widget.projectId,
//           onSelectedPeople: (people) {
//             setState(() {
//               _selectedPeople = people; // Capture selected people
//             });
//           },
//         ),
//       ),
//     );

//     if (selectedPeople != null) {
//       setState(() {
//         _selectedPeople = selectedPeople;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     Provider.of<ThemeNotifier>(context);

//     return AlertDialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//       title: Text(widget.isEdit ? 'Edit Task' : 'Add Task'),  // Differentiating between Add and Edit
//       content: SingleChildScrollView(
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               // Title Field
//               TextFormField(
//                 controller: _titleController,
//                 decoration: const InputDecoration(labelText: 'Title'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter a title';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 10),

//               // Status Dropdown
//               DropdownButtonFormField<String>(
//                 value: _TaskModal.statusOptions.any((status) => status['id'] == _selectedStatus) ? _selectedStatus : null,
//                 decoration: const InputDecoration(labelText: 'Status'),
//                 icon: const Icon(Icons.arrow_downward),
//                 iconSize: 24,
//                 elevation: 16,
//                 style: const TextStyle(color: Colors.black),
//                 onChanged: (String? newValue) {
//                   setState(() {
//                     _selectedStatus = newValue!;
//                   });
//                 },
//                 items: _TaskModal.statusOptions.map<DropdownMenuItem<String>>((status) {
//                   return DropdownMenuItem<String>(
//                     value: status['id'],
//                     child: Row(
//                       children: [
//                         Icon(Icons.circle, color: _getStatusColor(status['name']), size: 12),
//                         const SizedBox(width: 8),
//                         Text(status['name']),
//                       ],
//                     ),
//                   );
//                 }).toList(),
//               ),
//               const SizedBox(height: 10),

//               // Description Field
//               TextFormField(
//                 controller: _descriptionController,
//                 decoration: const InputDecoration(labelText: 'Description'),
//                 maxLines: 3,
//               ),
//               const SizedBox(height: 10),

//               // Only show file upload and member addition for Add Task
//               if (!widget.isEdit) ...[
//                 ElevatedButton.icon(
//                   onPressed: _pickFile,
//                   icon: const Icon(Icons.attach_file),
//                   label: const Text('Upload File'),
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: Colors.green,
//                   ),
//                 ),
//                 const SizedBox(height: 10),

//                 Wrap(
//                   spacing: 8.0,
//                   children: _files.map((file) {
//                     return Chip(
//                       label: Text(file.path.split('/').last),
//                       deleteIcon: const Icon(Icons.cancel, color: Colors.red), // 'X' button
//                       onDeleted: () => _removeFile(file), // Remove file on delete button click
//                     );
//                   }).toList(),
//                 ),
//                 const SizedBox(height: 10),

//                 ElevatedButton.icon(
//                   onPressed: _openAddPeoplePage,
//                   icon: const Icon(Icons.person_add),
//                   label: const Text('Add Members'),
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//               ],

//               // Always show selected members for both Add and Edit Task
//               Wrap(
//                 spacing: 8.0,
//                 runSpacing: 8.0,
//                 children: _selectedPeople.map((person) {
//                   return Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       GestureDetector(
//                         onTap: () {
//                           // Handle tap on avatar function, if needed
//                         },
//                         child: CircleAvatar(
//                           radius: 30,
//                           backgroundImage: person['profile_image'] != null && person['profile_image'].isNotEmpty
//                               ? NetworkImage(person['profile_image'])
//                               : const AssetImage('assets/default_avatar.png') as ImageProvider,
//                         ),
//                       ),
//                       const SizedBox(height: 5),
//                       Text(
//                         person['name'] ?? 'No Name',
//                         style: const TextStyle(fontSize: 12),
//                       ),
//                     ],
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () {
//             Navigator.pop(context);
//           },
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: _saveTask,
//           style: ElevatedButton.styleFrom(
//             foregroundColor: Colors.black,
//             backgroundColor: Colors.amber,
//           ),
//           child: const Text('Save'),
//         ),
//       ],
//     );
//   }

//   Color _getStatusColor(String statusName) {
//     switch (statusName) {
//       case 'Pending':
//         return Colors.orange;
//       case 'Processing':
//         return Colors.blue;
//       case 'Finished':
//         return Colors.green;
//       default:
//         return Colors.black;
//     }
//   }
// }

// class AddPeoplePageWorkTracking extends StatefulWidget {
//   final String asId;
//   final String projectId;
//   final Function(List<Map<String, dynamic>>) onSelectedPeople;

//   const AddPeoplePageWorkTracking({
//     super.key,
//     required this.asId,
//     required this.projectId,
//     required this.onSelectedPeople,
//   });

//   @override
//   _AddPeoplePageWorkTrackingState createState() => _AddPeoplePageWorkTrackingState();
// }

// class _AddPeoplePageWorkTrackingState extends State<AddPeoplePageWorkTracking> {
//   List<Map<String, dynamic>> _members = [];
//   final List<Map<String, dynamic>> _selectedPeople = [];
//   String _searchQuery = '';
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchProjectMembers(); // Fetch available members for the project
//   }

//   Future<void> _fetchProjectMembers() async {
//     setState(() {
//       _isLoading = true; // Set loading state
//     });

//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('token'); // Fetch the token from storage

//       if (token == null) {
//         throw Exception('No token found. Please log in again.');
//       }

//       // Fetch project members from the backend
//       final url = Uri.parse(
//           'https://demo-application-api.flexiflows.co/api/work-tracking/project-member/members?project_id=${widget.projectId}');
//       final response = await http.get(url, headers: {
//         'Authorization': 'Bearer $token', // Pass the token in the headers
//       });

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final List<dynamic> membersList = data['results'];

//         // Filter and prepare the list of members
//         setState(() {
//           _members = membersList.map<Map<String, dynamic>>((member) {
//             return {
//               'name': member['name'] ?? 'No Name',
//               'surname': member['surname'] ?? '',
//               'email': member['email'] ?? 'Unknown Email',
//               'employee_id': member['employee_id'],
//               'isSelected': false, // Track selection
//             };
//           }).toList();
//         });
//       } else {
//         throw Exception('Failed to load project members');
//       }
//     } catch (e) {
//       print('Error fetching project members: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching project members: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false; // Loading is done
//       });
//     }
//   }

//   Future<void> _fetchProfileImages() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('token'); // Fetch the token from storage

//       if (token == null) {
//         throw Exception('No token found. Please log in again.');
//       }

//       // Fetch profile images for each member
//       for (var member in _members) {
//         final employeeId = member['employee_id'];
//         final response = await http.get(
//           Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
//           headers: {
//             'Authorization': 'Bearer $token', // Include the token in the request headers
//           },
//         );

//         if (response.statusCode == 200) {
//           final profileData = jsonDecode(response.body);
//           setState(() {
//             member['images'] = profileData['images'] ?? ''; // Update the image URL
//           });
//         } else {
//           print('Failed to load profile image for $employeeId: ${response.body}');
//         }
//       }
//     } catch (e) {
//       print('Error fetching profile images: $e');
//     }
//   }

//   void _toggleSelection(int index) {
//     setState(() {
//       _members[index]['isSelected'] = !_members[index]['isSelected'];
//     });
//   }

//   void _onAddMembersPressed() {
//     final selectedMembers = _members.where((member) => member['isSelected']).toList();
//     if (selectedMembers.isNotEmpty) {
//       widget.onSelectedPeople(selectedMembers); // Return selected members
//       Navigator.pop(context);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select at least one member')),
//       );
//     }
//   }

//   Future<void> _confirmSelection() async {
//     final selectedMembers = _members.where((member) => member['isSelected']).toList();

//     // Map the selected members' employee_id to be sent to the backend
//     final List<Map<String, dynamic>> memberDetails = selectedMembers
//         .map<Map<String, dynamic>>((member) => {'employee_id': member['employee_id']})
//         .toList();

//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('token'); // Fetch token for authenticated requests

//       if (token == null) {
//         throw Exception('No token found');
//       }

//       final url = Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/assignment-members/insert');
//       final response = await http.post(
//         url,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'assignment_id': widget.asId, // Pass the assignment ID
//           'memberDetails': memberDetails, // Pass the selected members
//         }),
//       );

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Members added successfully!')),
//         );
//         Navigator.pop(context, true); // Close modal and return success
//       } else {
//         throw Exception('Failed to add members');
//       }
//     } catch (e) {
//       print('Error adding members: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error adding members: $e')),
//       );
//     }
//   }

//   void _showMemberDetails(String employeeName) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Member Details'),
//         content: Text('Employee Name: $employeeName'),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//             },
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Filter members based on the search query
//     final filteredMembers = _members.where((member) {
//       final memberName = member['name']?.toLowerCase() ?? '';
//       return memberName.contains(_searchQuery.toLowerCase());
//     }).toList();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Add People',
//           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//         ),
//         flexibleSpace: ClipPath(
//           clipper: CustomAppBarClipper(),
//           child: Container(
//             decoration: const BoxDecoration(
//               image: DecorationImage(
//                 image: AssetImage('assets/background.png'),
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//         ),
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator()) // Show loading indicator when loading
//           : Column(
//         children: [
//           // Search bar
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
//             child: TextField(
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//               decoration: InputDecoration(
//                 prefixIcon: const Icon(Icons.search),
//                 hintText: 'Search',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30.0),
//                 ),
//               ),
//             ),
//           ),
//           // Member list
//           Expanded(
//             child: ListView.builder(
//               itemCount: filteredMembers.length,
//               itemBuilder: (context, index) {
//                 final member = filteredMembers[index];
//                 final imageUrl = member['image'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

//                 return Card(
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10.0),
//                   ),
//                   child: ListTile(
//                     leading: GestureDetector(
//                       onTap: () => _showMemberDetails(member['name']), // Show member details on tap
//                       child: CircleAvatar(
//                         backgroundImage: NetworkImage(imageUrl),
//                         onBackgroundImageError: (exception, stackTrace) {
//                           if (kDebugMode) {
//                             print('Error loading image for employee ${member['employee_id']}: $exception');
//                           }
//                         },
//                       ),
//                     ),
//                     title: Text(member['name'] ?? 'No Name'),
//                     subtitle: Text('${member['surname']} - ${member['email']}'),
//                     trailing: Checkbox(
//                       value: member['isSelected'], // Checkbox for selecting the member
//                       onChanged: (bool? value) {
//                         _toggleSelection(index); // Toggle selection on checkbox change
//                       },
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           // Button to confirm selected members
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: ElevatedButton.icon(
//               onPressed: () {
//                 _onAddMembersPressed(); // Confirm selected members
//                 _confirmSelection(); // Confirm and save the selected members
//               },
//               icon: const Icon(Icons.add),
//               label: const Text('Add Members'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.amber,
//                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(30.0),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class PdfViewer extends StatelessWidget {
//   final String filePath;

//   const PdfViewer({super.key, required this.filePath});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('PDF Viewer'),
//       ),
//       body: PDFView(
//         filePath: filePath,
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/backup_project_management_page.dart';
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
        return _TaskModal(
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
        return _TaskModal(
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
              Tab(text: 'Processing / Detail'),
              Tab(text: 'Assignment/Task'), 
              Tab(text: 'Comment / Chat'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProcessingOrDetailTab(filteredTasks), 
                _buildAssignmentorTaskTab(filteredTasks),
                _buildChatAndConversationTab(isDarkMode),
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
          // Status row with clock icon
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
               const Icon(
                Icons.access_time, // Clock icon
                color: Colors.amber, // Yellow color for the clock icon
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
      TextSpan(
        text: 'Title: ', // Add the "Title:" label
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontSize: 20,
        ),
      ),
      TextSpan(
        text: task['title'] ?? 'No Title', // Display the actual task title
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          fontSize: 20,
        ),
      ),
    ],
  ),
),

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
                label: 'Time: 09:00 AM - 12:00 PM', // Can adjust the time display dynamically if needed
                iconColor: Colors.redAccent,
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
          const SizedBox(height: 12),
          // Task description
         
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


class _TaskModal extends StatefulWidget {
  final Map<String, dynamic>? task;
  final Function(Map<String, dynamic>) onSave;
  final bool isEdit;
  final String projectId;
  final String baseUrl;

  static const List<Map<String, dynamic>> statusOptions = [
    {'id': '40d2ba5e-a978-47ce-bc48-caceca8668e9', 'name': 'Pending'},
    {'id': '0a8d93f0-1c05-42b2-8e56-984a578ef077', 'name': 'Processing'},
    {'id': 'e35569eb-75e1-4005-9232-bfb57303b8b3', 'name': 'Finished'},
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
    _descriptionController = TextEditingController(text: widget.task?['description'] ?? '');

    _selectedStatus = widget.task?['status'] ?? _TaskModal.statusOptions.first['id'];

    if (widget.isEdit) {
      _fetchAssignmentMembers();
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
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'mp4'],
    );

    // If the user picks a file, add it to the _files list
    if (result != null) {
      setState(() {
        _files.addAll(result.paths.map((path) => File(path!)).toList());
      });
    } else {
      // If no file is selected, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected')),
      );
    }
  }

// Function to remove a file from the _files list
  void _removeFile(File file) {
    setState(() {
      _files.remove(file);
    });
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token is null. Please log in again.')),
        );
        return;
      }

      // Prepare task data for both adding and editing
      final taskData = {
        'status_id': _selectedStatus,
        'title': _titleController.text,
        'descriptions': _descriptionController.text,
        'memberDetails': jsonEncode([
          {'employee_id': '12345', 'role': 'Manager'}, // Example memberDetails structure
          {'employee_id': '67890', 'role': 'Developer'}
        ]),
      };

      try {
        // Check if it's an edit action
        if (widget.isEdit && widget.task != null) {
          // Edit Task API (PUT)
          final response = await http.put(
            Uri.parse('${widget.baseUrl}/api/work-tracking/ass/update/${widget.task!['as_id']}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(taskData),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task saved successfully')),
            );
            Navigator.pop(context, true);
          } else {
            final responseBody = response.body;
            print('Failed to save task: ${response.statusCode}, Response: $responseBody');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save task: $responseBody')),
            );
          }
        } else {
          // Add Task API (POST) - Creating a new task
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('${widget.baseUrl}/api/work-tracking/ass/insert'),
          );

          request.headers['Authorization'] = 'Bearer $token';
          request.fields['project_id'] = widget.projectId;
          request.fields['status_id'] = _selectedStatus;
          request.fields['title'] = _titleController.text;
          request.fields['descriptions'] = _descriptionController.text;
          request.fields['memberDetails'] = taskData['memberDetails'] ?? ''; // Fix for nullable String

          // Attach files (if any)
          if (_files.isNotEmpty) {
            for (var file in _files) {
              request.files.add(
                await http.MultipartFile.fromPath(
                  'file_name',
                  file.path,
                ),
              );
            }
          }

          final response = await request.send();

          if (response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task added successfully')),
            );
            Navigator.pop(context, true);
          } else {
            final errorResponse = await response.stream.bytesToString();
            print('Failed to add task: StatusCode: ${response.statusCode}, Error: $errorResponse');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add task: $errorResponse')),
            );
          }
        }
      } on SocketException catch (e) {
        print('Network error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      } on FormatException catch (e) {
        print('Response format error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid response format from the server.')),
        );
      } catch (e) {
        print('Unexpected error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e')),
        );
      }
    }
  }

  void _openAddPeoplePage() async {
    final selectedPeople = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPeoplePageWorkTracking(
          asId: widget.projectId, // Pass the asId (assignment ID)
          projectId: widget.projectId,
          onSelectedPeople: (people) {
            setState(() {
              _selectedPeople = people; // Capture selected people
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
    titlePadding: EdgeInsets.zero,
    title: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const Text(
            'Processing or Detail',
            style: TextStyle(color: Colors.black, fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 48), // To keep the title centered
        ],
      ),
    ),
    content: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saveTask,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Title Field
              const Text(
                'Title',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Status and Upload Image in the same row
              Row(
                children: [
                  Expanded(
                    flex: 2, // Adjusts width ratio for the status dropdown
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<String>(
                          value: _TaskModal.statusOptions.any((status) => status['id'] == _selectedStatus)
                              ? _selectedStatus
                              : null,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          ),
                          icon: const Icon(Icons.arrow_downward),
                          style: const TextStyle(color: Colors.black),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedStatus = newValue!;
                            });
                          },
                          items: _TaskModal.statusOptions.map<DropdownMenuItem<String>>((status) {
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 1, // Adjusts width ratio for the upload button
                    child: ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14), // Shorter button
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 15),
              // Only show file upload and member addition for Add Task
              if (!widget.isEdit) ...[
                ElevatedButton.icon(
                  onPressed: _openAddPeoplePage,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add People'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),

                Wrap(
                  spacing: 8.0,
                  children: _files.map((file) {
                    return Chip(
                      label: Text(file.path.split('/').last),
                      deleteIcon: const Icon(Icons.cancel, color: Colors.red),
                      onDeleted: () => _removeFile(file),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
              ],

              // Always show selected members for both Add and Edit Task
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _selectedPeople.map((person) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Handle tap on avatar function, if needed
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: person['profile_image'] != null && person['profile_image'].isNotEmpty
                              ? NetworkImage(person['profile_image'])
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        person['name'] ?? 'No Name',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                }).toList(),
              ),
              // Description Field
              const Text(
                'Description',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    ),
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
  final String projectId;
  final Function(List<Map<String, dynamic>>) onSelectedPeople;

  const AddPeoplePageWorkTracking({
    super.key,
    required this.asId,
    required this.projectId,
    required this.onSelectedPeople,
  });

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
    _fetchProjectMembers(); // Fetch available members for the project
  }

  Future<void> _fetchProjectMembers() async {
    setState(() {
      _isLoading = true; // Set loading state
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // Fetch the token from storage

      if (token == null) {
        throw Exception('No token found. Please log in again.');
      }

      // Fetch project members from the backend
      final url = Uri.parse(
          'https://demo-application-api.flexiflows.co/api/work-tracking/project-member/members?project_id=${widget.projectId}');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token', // Pass the token in the headers
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> membersList = data['results'];

        // Filter and prepare the list of members
        setState(() {
          _members = membersList.map<Map<String, dynamic>>((member) {
            return {
              'name': member['name'] ?? 'No Name',
              'surname': member['surname'] ?? '',
              'email': member['email'] ?? 'Unknown Email',
              'employee_id': member['employee_id'],
              'isSelected': false, // Track selection
            };
          }).toList();
        });
      } else {
        throw Exception('Failed to load project members');
      }
    } catch (e) {
      print('Error fetching project members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching project members: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Loading is done
      });
    }
  }

  Future<void> _fetchProfileImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // Fetch the token from storage

      if (token == null) {
        throw Exception('No token found. Please log in again.');
      }

      // Fetch profile images for each member
      for (var member in _members) {
        final employeeId = member['employee_id'];
        final response = await http.get(
          Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
          headers: {
            'Authorization': 'Bearer $token', // Include the token in the request headers
          },
        );

        if (response.statusCode == 200) {
          final profileData = jsonDecode(response.body);
          setState(() {
            member['images'] = profileData['images'] ?? ''; // Update the image URL
          });
        } else {
          print('Failed to load profile image for $employeeId: ${response.body}');
        }
      }
    } catch (e) {
      print('Error fetching profile images: $e');
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      _members[index]['isSelected'] = !_members[index]['isSelected'];
    });
  }

  void _onAddMembersPressed() {
    final selectedMembers = _members.where((member) => member['isSelected']).toList();
    if (selectedMembers.isNotEmpty) {
      widget.onSelectedPeople(selectedMembers); // Return selected members
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
    }
  }

Future<void> _confirmSelection() async {
  final selectedMembers = _members.where((member) => member['isSelected']).toList();

  // Ensure that only valid employee IDs are included in the request
  final List<Map<String, dynamic>> memberDetails = selectedMembers
      .map<Map<String, dynamic>>((member) => {
        if (member['employee_id'] != null && member['employee_id'].isNotEmpty)
          'employee_id': member['employee_id']
      })
      .where((member) => member.containsKey('employee_id')) // Filter out any empty entries
      .toList();

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // Fetch token for authenticated requests

    if (token == null) {
      throw Exception('No token found');
    }

    final url = Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/assignment-members/update/${widget.projectId}'); // Updated URL for member update
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'assignment_id': widget.asId, // Pass the assignment ID
        'memberDetails': memberDetails, // Pass the selected members
      }),
    );

    // Print status code and body to help debug
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Members updated successfully!');
      Navigator.pop(context, true); // Close modal and return success
    } else {
      final responseBody = jsonDecode(response.body);
      throw Exception('Failed to update members: ${responseBody['error'] ?? response.body}');
    }
  } catch (e) {
    print('Error updating members: $e');
   
  }
}

  void _showMemberDetails(String employeeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Member Details'),
        content: Text('Employee Name: $employeeName'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter members based on the search query
    final filteredMembers = _members.where((member) {
      final memberName = member['name']?.toLowerCase() ?? '';
      return memberName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add People',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: ClipPath(
          clipper: CustomAppBarClipper(),
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator when loading
          : Column(
        children: [
          // Search bar
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
          // Member list
          Expanded(
            child: ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                final imageUrl = member['image'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => _showMemberDetails(member['name']), // Show member details on tap
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(imageUrl),
                        onBackgroundImageError: (exception, stackTrace) {
                          if (kDebugMode) {
                            print('Error loading image for employee ${member['employee_id']}: $exception');
                          }
                        },
                      ),
                    ),
                    title: Text(member['name'] ?? 'No Name'),
                    subtitle: Text('${member['surname']} - ${member['email']}'),
                    trailing: Checkbox(
                      value: member['isSelected'], // Checkbox for selecting the member
                      onChanged: (bool? value) {
                        _toggleSelection(index); // Toggle selection on checkbox change
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          // Button to confirm selected members
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                _onAddMembersPressed(); // Confirm selected members
                _confirmSelection(); // Confirm and save the selected members
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Members'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
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
