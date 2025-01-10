import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatCommentApprovalSection extends StatefulWidget {
  final String id;
  const ChatCommentApprovalSection({
    super.key,
    required this.id,
  });

  @override
  _ChatCommentApprovalSectionState createState() => _ChatCommentApprovalSectionState();
}

class _ChatCommentApprovalSectionState extends State<ChatCommentApprovalSection> {
  List<Map<String, dynamic>> _messages = [];
  final String _currentUserId = 'user_1'; // Update based on actual user ID logic
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchChatMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Fetch chat messages from the API
  Future<void> _fetchChatMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String endpoint = '/api/office-administration/car_permit/reply/${widget.id}';
    final String url = '$baseUrl$endpoint';

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Authentication token not found.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> results = data['results'];

        setState(() {
          _messages = results.map<Map<String, dynamic>>((item) {
            return {
              'comments': item['comment'],
              'created_at': item['created_at'],
              'createBy_name': '${item['employee_name']} ${item['employee_surname']}',
              'created_by': item['created_by'],
            };
          }).toList();

          // Sort messages chronologically (oldest first)
          _messages.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
          _isLoading = false;
        });

        // Scroll to the bottom to show the latest message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load messages. Status Code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred while fetching messages.';
      });
    }
  }

  // Send a message to the API
  Future<void> _sendMessage() async {
    final String message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String adminEndpoint = '/api/office-administration/car_permit/admin-reply/${widget.id}';
    final String userEndpoint = '/api/office-administration/car_permit/reply/${widget.id}';
    final String adminUrl = '$baseUrl$adminEndpoint';
    final String userUrl = '$baseUrl$userEndpoint';

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Authentication token not found.';
        });
        return;
      }

      // Determine user role
      final bool isAdmin = _currentUserId.startsWith('admin'); // Update based on actual role logic

      // Prepare payload
      final Map<String, dynamic> payload = {
        'detail': message,
        // 'ref_permit_uid': "", // Optional, omitted as per requirement
      };

      // Function to attempt sending to a specific URL
      Future<http.Response> attemptSend(String url) {
        return http.put(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(payload),
        );
      }

      http.Response response;

      if (isAdmin) {
        response = await attemptSend(adminUrl);
        if (response.statusCode != 200 && response.statusCode != 201) {
          // If admin API fails, try user API
          response = await attemptSend(userUrl);
        }
      } else {
        // Non-admin users use the user API directly
        response = await attemptSend(userUrl);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Message sent successfully
        setState(() {
          _messages.add({
            'comments': message,
            'created_at': DateTime.now().toIso8601String(),
            'createBy_name': 'You',
            'created_by': _currentUserId,
          });
          _isLoading = false;
          _messageController.clear();
        });

        // Scroll to the bottom to show the new message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to send message. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred while sending the message.';
      });
    }
  }

  // Assign a pastel color based on user ID
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

  // Format the date header
  String _formatDateHeader(DateTime messageDate) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    final DateTime msgDate = DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('dd-MM-yyyy').format(messageDate);
    }
  }

  // Format the time portion
  String _formatTimestamp(String timestamp) {
    final DateTime messageTime = DateTime.parse(timestamp).toLocal();
    return DateFormat('hh:mm a').format(messageTime);
  }

  // Build chat bubbles with date grouping
  List<Widget> _buildMessageList(bool isDarkMode) {
    List<Widget> messageWidgets = [];
    String? lastDate;

    for (var message in _messages) {
      final DateTime msgDate = DateTime.parse(message['created_at']).toLocal();
      final String dateHeader = _formatDateHeader(msgDate);

      if (lastDate != dateHeader) {
        // Add date header
        messageWidgets.add(
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                dateHeader,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        );
        lastDate = dateHeader;
      }

      // Add chat bubble
      messageWidgets.add(_buildChatBubble(message, isDarkMode));
    }

    return messageWidgets;
  }

  // Build individual chat bubble
  Widget _buildChatBubble(Map<String, dynamic> message, bool isDarkMode) {
    final bool isSentByMe = (message['created_by'] == _currentUserId);
    final String senderName = isSentByMe ? 'You' : (message['createBy_name'] ?? 'Unknown');

    final Color bubbleColor = isSentByMe ? Colors.blue.shade200 : _assignChatBubbleColor(message['created_by']);
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Alignment bubbleAlignment = isSentByMe ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: bubbleAlignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: bubbleColor,
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
            if (!isSentByMe)
              Text(
                senderName,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
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
    );
  }

  // Build the chat input field
  Widget _buildChatInput(bool isDarkMode) {
    final Color backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
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
            // Input field
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
                onSubmitted: (value) {
                  _sendMessage();
                },
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(Icons.send, color: Colors.white),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Comment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Loading Indicator or Error Message
          if (_isLoading && _messages.isEmpty)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null && _messages.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            )
          else
            // Message List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchChatMessages,
                child: _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages available.',
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        ),
                      )
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        children: _buildMessageList(isDarkMode),
                      ),
              ),
            ),

          // Display error message if sending fails
          if (_errorMessage != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),

          // Chat Input
          _buildChatInput(isDarkMode),
        ],
      ),
    );
  }
}
