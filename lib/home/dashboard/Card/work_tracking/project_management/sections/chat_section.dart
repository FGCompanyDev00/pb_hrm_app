// chat_section.dart

// ignore_for_file: unused_field, unused_element, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChatSection extends StatefulWidget {
  final String projectId;
  final String baseUrl;
  final String currentUserId;

  const ChatSection({
    super.key,
    required this.projectId,
    required this.baseUrl,
    required this.currentUserId,
  });

  @override
  ChatSectionState createState() => ChatSectionState();
}

class ChatSectionState extends State<ChatSection> {
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final WorkTrackingService _workTrackingService = WorkTrackingService();
  String _currentUserId = '';
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUserId;
    _loadCurrentUser();
    _loadChatMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
    });
  }

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
          _currentUserId = data['results'][0]['id']; // Set current user ID
          _currentUserName =
              data['results'][0]['employee_name']; // Set current user name
        });
      }
    }
  }

  Future<void> _loadChatMessages() async {
    try {
      final messages =
          await _workTrackingService.fetchChatMessages(widget.projectId);
      setState(() {
        _messages = messages.map((message) {
          return {
            ...message,
            'createBy_name': message['created_by'] == _currentUserId
                ? 'You'
                : message['createBy_name'],
          };
        }).toList();
      });
      _scrollToBottom();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load chat messages: $e');
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

  String _formatDate(String timestamp) {
    final DateTime messageDate = DateTime.parse(timestamp);
    final DateTime now = DateTime.now();

    if (messageDate.year == now.year &&
        messageDate.month == now.month &&
        messageDate.day == now.day) {
      return 'Today';
    } else if (messageDate.year == now.year &&
        messageDate.month == now.month &&
        messageDate.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd MMM yyyy').format(messageDate);
    }
  }

  String _formatTimestamp(String timestamp) {
    final DateTime messageTime = DateTime.parse(timestamp);
    return DateFormat('hh:mm a')
        .format(messageTime); // Time in hh:mm AM/PM format
  }

  Color _assignChatBubbleColor(String userId, bool isDarkMode) {
    final List<Color> lightModeColors = [
      const Color(0xFFE3F2FD), // Soft Blue
      const Color(0xFFF3E5F5), // Soft Purple
      const Color(0xFFFCE4EC), // Soft Pink
      const Color(0xFFF1F8E9), // Soft Green
      const Color(0xFFFFF3E0), // Soft Orange
    ];

    final List<Color> darkModeColors = [
      const Color(0xFF1A237E).withOpacity(0.7), // Deep Blue
      const Color(0xFF4A148C).withOpacity(0.7), // Deep Purple
      const Color(0xFF880E4F).withOpacity(0.7), // Deep Pink
      const Color(0xFF1B5E20).withOpacity(0.7), // Deep Green
      const Color(0xFFE65100).withOpacity(0.7), // Deep Orange
    ];

    final colors = isDarkMode ? darkModeColors : lightModeColors;
    final int hashValue = userId.hashCode % colors.length;
    return colors[hashValue];
  }

  void _showDeleteConfirmation(String commentId) {
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

  Future<void> _deleteMessage(String commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token is null. Please log in again.')),
        );
      }
      return;
    }

    final url = Uri.parse(
        '${widget.baseUrl}/api/work-tracking/project-comments/delete/$commentId');

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted successfully')),
        );
      }
    } else {
      final responseData = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to delete message: ${responseData['error'] ?? 'Unknown error'}')),
        );
      }
    }
  }

  Widget _buildChatAndConversationTab(bool isDarkMode) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse:
                true, // Reverse the order of the list to show the latest message at the bottom
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final nextMessage =
                  index + 1 < _messages.length ? _messages[index + 1] : null;

              // Check if the date of the current message is different from the next one (since list is reversed)
              final bool isNewDate = nextMessage == null ||
                  _formatDate(message['created_at']) !=
                      _formatDate(nextMessage['created_at']);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isNewDate) // Display date header
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          _formatDate(message['created_at']),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  _buildChatMessage(message, isDarkMode), // Message bubble
                ],
              );
            },
          ),
        ),
        _buildChatInput(isDarkMode), // Chat input at the bottom
      ],
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> message, bool isDarkMode) {
    final bool isSentByMe = message['created_by'] == _currentUserId;
    final String senderName =
        isSentByMe ? 'You' : message['createBy_name'] ?? 'Unknown';

    final Color messageColor = isSentByMe
        ? (isDarkMode
            ? Colors.blue.shade900.withOpacity(0.7)
            : Colors.blue.shade100)
        : _assignChatBubbleColor(message['created_by'], isDarkMode);

    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color timestampColor =
        isDarkMode ? Colors.grey[300]! : Colors.grey[600]!;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 1.0,
        child: Align(
          alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: EdgeInsets.only(
              bottom: 8,
              left: isSentByMe ? 50 : 8,
              right: isSentByMe ? 8 : 50,
            ),
            child: Column(
              crossAxisAlignment: isSentByMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isSentByMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: messageColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isSentByMe ? 20 : 5),
                      topRight: Radius.circular(isSentByMe ? 5 : 20),
                      bottomLeft: const Radius.circular(20),
                      bottomRight: const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message['comments'] ?? '',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(message['created_at']!),
                        style: TextStyle(
                          color: timestampColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput(bool isDarkMode) {
    final Color backgroundColor = isDarkMode
        ? Colors.grey[850]!.withOpacity(0.95)
        : Colors.white.withOpacity(0.95);
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 26.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                ),
                maxLines: null,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.blue[700]!, Colors.purple[700]!]
                    : [Colors.blue[400]!, Colors.purple[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.purple[700]!.withOpacity(0.3)
                      : Colors.purple[400]!.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  if (_messageController.text.isNotEmpty) {
                    _sendMessage(_messageController.text);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return _buildChatAndConversationTab(isDarkMode);
  }
}
