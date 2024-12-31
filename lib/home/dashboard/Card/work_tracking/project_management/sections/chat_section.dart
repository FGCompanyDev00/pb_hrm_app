// chat_section.dart

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
          _currentUserName = data['results'][0]['employee_name']; // Set current user name
        });
      }
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted successfully')),
        );
      }
    } else {
      final responseData = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: ${responseData['error'] ?? 'Unknown error'}')),
        );
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
              final bool isNewDate = nextMessage == null || _formatDate(message['created_at']) != _formatDate(nextMessage['created_at']);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isNewDate) // Display date header
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          _formatDate(message['created_at']),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
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
    final String senderName = isSentByMe ? 'You' : message['createBy_name'] ?? 'Unknown';

    // Determine the message bubble color
    final Color messageColor = isSentByMe
        ? Colors.blue.shade200 // Your own messages (light blue)
        : _assignChatBubbleColor(message['created_by']); // Different color for others

    // Text color based on the dark mode theme
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    // Align the message to the right for sent messages, left for others
    final Alignment messageAlignment = isSentByMe ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: messageAlignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
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
    );
  }

  Widget _buildChatInput(bool isDarkMode) {
    final Color backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color sendButtonColor = isDarkMode ? Colors.green[300]! : Colors.green;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 26.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(2, 1),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 300), // Animation duration
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.green, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      _sendMessage(_messageController.text);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
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
