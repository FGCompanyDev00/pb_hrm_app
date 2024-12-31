import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:intl/intl.dart';

class ChatCommentApprovalSection extends StatefulWidget {
  const ChatCommentApprovalSection({super.key});

  @override
  ChatCommentApprovalSectionState createState() => ChatCommentApprovalSectionState();
}

class ChatCommentApprovalSectionState extends State<ChatCommentApprovalSection> {
  // A sample list of chat messages for UI demonstration
  final List<Map<String, dynamic>> _messages = [
    {
      'comments': 'Hello, this is a test message',
      'created_at': '2024-01-01T10:00:00',
      'createBy_name': 'John Doe',
      'created_by': 'user_2',
    },
    {
      'comments': 'Another example message from me!',
      'created_at': '2024-01-01T11:30:00',
      'createBy_name': 'You',
      'created_by': 'user_1',
    },
    {
      'comments': 'This is an older message from Faiz to test for UI demonstration first',
      'created_at': '2023-12-31T19:45:00',
      'createBy_name': 'Faiz',
      'created_by': 'user_3',
    },
    {
      'comments': 'Hahahah you re funny',
      'created_at': '2023-12-31T21:45:00',
      'createBy_name': 'Naruto',
      'created_by': 'user_5',
    },
  ];

  // For demonstration, we assume the current user has this ID
  final String _currentUserId = 'user_1';

  // Scroll controller for the ListView
  final ScrollController _scrollController = ScrollController();

  // Controller for the bottom text field
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Just a small helper that returns a color for “other users” messages
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

  // Format the date portion (e.g., "Today", "Yesterday", or "dd MMM yyyy")
  String _formatDate(String timestamp) {
    final DateTime messageDate = DateTime.parse(timestamp);
    final DateTime now = DateTime.now();
    if (_isSameDay(messageDate, now)) {
      return 'Today';
    } else if (_isSameDay(messageDate, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    } else {
      return DateFormat('dd MMM yyyy').format(messageDate);
    }
  }

  // Helper to check if two dates are the same calendar day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  // Format the time portion (e.g., "10:00 AM")
  String _formatTimestamp(String timestamp) {
    final DateTime messageTime = DateTime.parse(timestamp);
    return DateFormat('hh:mm a').format(messageTime);
  }

  @override
  Widget build(BuildContext context) {
    // Check if dark mode is active
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
            // Expanded chat message list
            Expanded(
              child: ListView.builder(
                reverse: true, // Show latest message at the bottom
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final nextMessage = index + 1 < _messages.length ? _messages[index + 1] : null;

                  // Next Message is the latest one to display
                  final bool isNewDate = nextMessage == null || _formatDate(message['created_at']) != _formatDate(nextMessage['created_at']);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isNewDate)
                        // Date header
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              _formatDate(message['created_at']),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      _buildChatBubble(message, isDarkMode),
                    ],
                  );
                },
              ),
            ),

            // Bottom input field
            _buildChatInput(isDarkMode),
          ],
        ));
  }

  Widget _buildChatBubble(Map<String, dynamic> message, bool isDarkMode) {
    final bool isSentByMe = (message['created_by'] == _currentUserId);
    final String senderName = isSentByMe ? 'You' : (message['createBy_name'] ?? 'Unknown');

    // My own bubble is light blue, others get a random pastel
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

  Widget _buildChatInput(bool isDarkMode) {
    final Color backgroundColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

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
                // Note: no actual "send" logic here—design only
              ),
            ),
            const SizedBox(width: 8),
            // Send button (design only, does nothing)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
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
                    // No send logic—design only
                    _messageController.clear();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
