import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_office_booking_event_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DetailsPage extends StatefulWidget {
  final String types;
  final String id;
  final String status;

  const DetailsPage({
    super.key,
    required this.types,
    required this.id,
    required this.status,
  });

  @override
  DetailsPageState createState() => DetailsPageState();
}

class DetailsPageState extends State<DetailsPage> {
  Map<String, dynamic>? data;
  Map<int, String> _leaveTypes = {};
  bool isFinalized = false;
  bool isLoading = true;
  String? imageUrl;
  String? lineManagerImageUrl;
  String? hrImageUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLeaveTypes().then((_) {
      _fetchData();
    });
  }

  /// Handle refresh action
  Future<void> _handleRefresh() async {
    await _fetchData();
  }

  /// Fetch Leave Types
  Future<void> _fetchLeaveTypes() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String leaveTypesUrl = '$baseUrl/api/leave-types';
    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error',
            'Token not found. Please log in again.');
        setState(() {
          _errorMessage = 'Token not found. Please log in again.';
        });
        return;
      }
      final response = await http.get(
        Uri.parse(leaveTypesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenValue',
        },
      );

      if (kDebugMode) {
        debugPrint('Fetching Leave Types from URL: $leaveTypesUrl');
        debugPrint('Response Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] is List) {
          setState(() {
            _leaveTypes = {
              for (var lt in data['results']) lt['leave_type_id']: lt['name']
            };
          });
        } else {
          throw Exception('Failed to fetch leave types');
        }
      } else {
        throw Exception(
            'Failed to fetch leave types: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching leave types: $e';
      });
      if (kDebugMode) {
        debugPrint('Error fetching leave types: $e');
      }
    }
  }

  /// Fetch detailed data using appropriate API based on type
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    final String type = widget.types.toLowerCase();
    final String id = widget.id;
    final String status = widget.status;

    // Ensure the first letter is capitalized and the rest are lowercase
    String formattedStatus = '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}';

    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String apiUrl = '$baseUrl/api/app/users/history/pending/$id';

    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        setState(() {
          isLoading = false;
          _errorMessage = 'Token not found. Please log in again.';
        });
        return;
      }

      // Prepare request body
      Map<String, dynamic> requestBody = {
        'types': type,
        'status': formattedStatus,
      };

      if (kDebugMode) {
        debugPrint('Sending POST request to $apiUrl with body: $requestBody');
      }

      // Send POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenValue',
        },
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        debugPrint('Received response with status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('statusCode') &&
            (responseData['statusCode'] == 200 || responseData['statusCode'] == 201 || responseData['statusCode'] == 202)) {
          // Handle success
          if (!responseData.containsKey('results')) {
            _showErrorDialog('Error', 'Invalid API response structure.');
            setState(() {
              isLoading = false;
              _errorMessage = 'Invalid API response structure.';
            });
            return;
          }
          if (responseData['results'] is List) {
            final List<dynamic> dataList = responseData['results'];
            if (dataList.isNotEmpty) {
              setState(() {
                data = dataList[0] as Map<String, dynamic>;
                isLoading = false;
              });
            } else {
              setState(() {
                data = null;
                isLoading = false;
                _errorMessage = 'No data found.';
              });
            }
          } else if (responseData['results'] is Map) {
            final Map<String, dynamic> singleData = responseData['results'];
            setState(() {
              data = singleData;
              isLoading = false;
            });
          } else {
            setState(() {
              data = null;
              isLoading = false;
              _errorMessage = 'Unexpected data format.';
            });
            _showErrorDialog('Error', 'Unexpected data format.');
          }
        } else {
          // Handle API-level errors
          String errorMessage = responseData['message'] ?? 'Unknown error.';
          _showErrorDialog('Error', errorMessage);
          setState(() {
            isLoading = false;
            _errorMessage = errorMessage;
          });
        }
      } else {
        // Handle HTTP errors
        _showErrorDialog('Error', 'Failed to fetch details: ${response.statusCode}');
        setState(() {
          isLoading = false;
          _errorMessage = 'Failed to fetch details: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('Error fetching details: $e');
      setState(() {
        isLoading = false;
        _errorMessage = 'An unexpected error occurred while fetching details.';
      });
      _showErrorDialog('Error', 'An unexpected error occurred while fetching details.');
    }
  }

  /// Retrieve token from SharedPreferences
  Future<String?> _getToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      debugPrint('Error retrieving token: $e');
      return null;
    }
  }

  /// Format date string
  String formatDate(String? dateStr, {String? timeStr, bool includeTime = false, bool timeOnly = false}) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      final DateTime parsedDate = DateTime.parse(dateStr);

      if (timeOnly) {
        // Format only time in hh:mm - hh:mm
        return DateFormat('HH:mm').format(parsedDate);
      }

      if (includeTime && timeStr != null && timeStr.isNotEmpty) {
        final DateTime parsedDateTime = DateTime.parse('$dateStr $timeStr');
        return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDateTime);
      }

      // Default date format without time
      return DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      debugPrint('Date parsing error: $e');
      return 'Invalid Date';
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
            ),
            fit: BoxFit.cover,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      centerTitle: true,
      title: Text(
        'History Details',
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: isDarkMode ? Colors.white : Colors.black,
          size: 20,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      toolbarHeight: 80,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Build Requestor Section
  Widget _buildRequestorSection() {
    String requestorName =
        (data?['requestor_name'] ?? data?['employee_name'] ?? data?['created_by']) ?? 'No Name';

    final submittedOn = formatDate(
      data?['created_date'] ?? data?['date_create'] ?? data?['created_at'],
      includeTime: true,
    );

    String requestorImageUrl = data?['img_name'] ?? data?['img_path'] ?? '';

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Requestor',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: requestorImageUrl.isNotEmpty
                  ? NetworkImage(requestorImageUrl)
                  : NetworkImage(_defaultAvatarUrl()),
              radius: 30,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestorName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Submitted on $submittedOn',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                      isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A small highlight container to show the type
  Widget _buildBlueSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.7,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blue : Colors.lightBlue[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          '${widget.types[0].toUpperCase()}${widget.types.substring(1).toLowerCase()}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Build the main details
  Widget _buildDetailsSection() {
    final String type = widget.types.toLowerCase();
    final List<Map<String, dynamic>> details = [];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (type == 'meeting') {
      details.addAll([
        {
          'icon': Icons.bookmark,
          'title': 'Title',
          'value': data?['title'] ?? 'No Title',
          'color': Colors.blue
        },
        {
          'icon': Icons.calendar_today,
          'title': 'Date',
          'value':
          '${formatDate(data?["from_date_time"])} - ${formatDate(data?["to_date_time"])}',
          'color': Colors.green
        },
        {
          'icon': Icons.access_time,
          'title': 'Time',
          'value':
          '${formatDate(data?["from_date_time"], timeOnly: true)} - ${formatDate(data?["to_date_time"], timeOnly: true)}',
          'color': Colors.orange
        },
        {
          'icon': Icons.description,
          'title': 'Description',
          'value': data?['remark'] ?? 'No Remark',
          'color': Colors.indigo
        },
        {
          'icon': Icons.location_on,
          'title': 'Room',
          'value': data?['room_name'] ?? 'No room specified',
          'color': Colors.orange
        },
        {
          'icon': Icons.radar,
          'title': 'Status',
          'value': RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Status: ',
                ),
                TextSpan(
                  text: _capitalizeFirstLetter(data?['status'] ?? 'No status'),
                  style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(data?['status'] ?? 'no status')),
                ),
              ],
            ),
          ),
          'color': _getStatusColor(data?['status'] ?? 'no status')
        }
      ]);
    } else if (type == 'car') {
      details.addAll([
        {
          'icon': Icons.bookmark,
          'title': 'Purpose',
          'value': data?['purpose'] ?? 'No Purpose',
          'color': Colors.blue
        },
        {
          'icon': Icons.place,
          'title': 'Place',
          'value': data?['place'] ?? 'N/A',
          'color': Colors.green
        },
        {
          'icon': Icons.calendar_today,
          'title': 'Date & Time',
          'value':
          '${formatDate(data?["date_in"], timeStr: data?["time_in"], includeTime: true)} - '
              '${formatDate(data?["date_out"], timeStr: data?["time_out"], includeTime: true)}',
          'color': Colors.orange
        },
        {
          'icon': Icons.radar,
          'title': 'Status',
          'value': RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Status: ',
                ),
                TextSpan(
                  text: data?['status'] ?? 'No status',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(data?['status'] ?? 'no status')),
                ),
              ],
            ),
          ),
          'color': _getStatusColor(data?['status'] ?? 'no status')
        }
      ]);
    } else if (type == 'leave') {
      String leaveTypeName =
          _leaveTypes[data?['leave_type_id']] ?? 'Unknown Leave Type';
      details.addAll([
        {
          'icon': Icons.bookmark,
          'title': 'Title',
          'value': data?['name'] ?? 'No Title',
          'color': Colors.blue
        },
        {
          'icon': Icons.calendar_today,
          'title': 'Date',
          'value':
          '${formatDate(data?["take_leave_from"])} - ${formatDate(data?["take_leave_to"])}',
          'color': Colors.green
        },
        {
          'icon': Icons.label,
          'title': 'Type of leave',
          'value':
          '$leaveTypeName (${data?["days"]?.toString() ?? "N/A"})',
          'color': Colors.orange
        },
        {
          'icon': Icons.description,
          'title': 'Description',
          'value': data?['take_leave_reason'] ?? 'No Description Provided',
          'color': Colors.green
        },
        {
          'icon': Icons.radar,
          'title': 'Status',
          'value': RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Status: ',
                ),
                TextSpan(
                  text: data?['is_approve'] ?? 'No status',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(data?['is_approve'] ?? 'no status')),
                ),
              ],
            ),
          ),
          'color': _getStatusColor(data?['is_approve'] ?? 'no status')
        }
      ]);
    }

    else if (type == 'minutes of meeting') {
      details.addAll([
        {
          'icon': Icons.bookmark,
          'title': 'Title',
          'value': data?['title'] ?? 'No Title',
          'color': Colors.blue
        },
        {
          'icon': Icons.calendar_today,
          'title': 'Date',
          'value':
          '${formatDate(data?["fromdate"])} - ${formatDate(data?["todate"])}',
          'color': Colors.green
        },
        {
          'icon': Icons.access_time,
          'title': 'Time',
          'value':
          '${formatDate(data?["fromdate"], includeTime: true)} - ${formatDate(data?["todate"], includeTime: true)}',
          'color': Colors.orange
        },
        {
          'icon': Icons.description,
          'title': 'Description',
          'value': data?['description'] ?? 'No Description',
          'color': Colors.purple
        },
        {
          'icon': Icons.public,
          'title': 'Status',
          'value': data?['status'] ?? '',
          'color': Colors.red
        },
        {
          'icon': Icons.groups,
          'title': 'Members',
          'value': _buildMemberCircles(data?['guests'] ?? []),
          'color': Colors.indigo
        },
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Build each detail row
        for (final detail in details)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: _buildInfoRow(
              detail['icon'],
              detail['title'],
              detail['value'],
              detail['color'],
              isDarkMode,
            ),
          ),
        if (type == 'minutes of meeting')
          _buildDownloadButton(data?['file_name'] ?? '')
      ],
    );
  }

  Widget _buildMemberCircles(List<dynamic> guests) {
    if (guests.isEmpty) {
      return const Text('No members available');
    }

    return Wrap(
      spacing: 4,
      runSpacing: 10,
      children: guests.map<Widget>((guest) {
        final String imageUrl = guest['img_name'] ?? '';
        final String name = guest['employee_name'] ?? 'Unknown';

        return SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(imageUrl),
                onBackgroundImageError: (_, __) => const Icon(Icons.error),
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Download Button
  Widget _buildDownloadButton(String fileNameOrUrl) {
    // Hide if empty:
    if (fileNameOrUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: ElevatedButton.icon(
        onPressed: () async {
          // Open or download the file if have a direct URL
          // For demonstration, just print the URL
          if (kDebugMode) {
            print('Downloading from: $fileNameOrUrl');
          }
          // Use url_launcher or any other logic
          // Example:
          // if (await canLaunchUrlString(fileNameOrUrl)) {
          //   await launchUrlString(fileNameOrUrl);
          // }
        },
        icon: const Icon(Icons.download),
        label: const Text('Download Attachment'),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, dynamic content, Color color, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 24,
          color: isDarkMode ? color.withOpacity(0.8) : color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: content is Widget
              ? content
              : Text(
            '$title: $content',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  /// Status color helper
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'yes':
        return Colors.green;
      case 'reject':
      case 'rejected':
      case 'no':
        return Colors.red;
      case 'waiting':
      case 'pending':
      case 'branch waiting':
        return Colors.amber;
      case 'processing':
      case 'branch processing':
        return Colors.blue;
      case 'completed':
        return Colors.orange;
      case 'deleted':
      case 'disapproved':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildWorkflowSection() {
    // Build a little arrow icon in between avatars
    Widget buildArrow() => const Padding(
      padding: EdgeInsets.only(top: 15.0),
      child: Icon(Icons.arrow_forward, color: Colors.grey, size: 18),
    );

    final bool isLeaveType = widget.types.toLowerCase() == 'leave';
    final List<dynamic> detailsList = data?['details'] ?? [];

    // ----------------------------------------------------------------
    //  1) REQUESTOR (FIRST AVATAR)
    // ----------------------------------------------------------------
    final String requestorImg = (data?['img_name'] as String?)?.isNotEmpty == true
        ? data!['img_name'] as String
        : 'assets/avatar_placeholder.png';

    // The border color for the requestor is based on data?['status']
    final Color requestorBorderColor = _getStatusColor(data?['status'] ?? data?['is_approve'] ?? '');

    // ----------------------------------------------------------------
    //  2) SECOND AVATAR (from details[0] if it exists)
    // ----------------------------------------------------------------
    String secondImg = 'assets/avatar_placeholder.png';
    Color secondBorderColor = Colors.grey;
    if (detailsList.isNotEmpty) {
      final detail = detailsList[0];
      secondImg = (detail['img_name'] as String?)?.isNotEmpty == true
          ? detail['img_name']
          : 'assets/avatar_placeholder.png';
      secondBorderColor = _getStatusColor(detail['decide'] ?? detail['detail'] ?? '');

    }

    // ----------------------------------------------------------------
    //  3) THIRD AVATAR (ONLY FOR LEAVE TYPE, from details[1] if it exists)
    // ----------------------------------------------------------------
    // Even if details is empty or only has one item, we'll still show it with placeholder
    String thirdImg = 'assets/avatar_placeholder.png';
    Color thirdBorderColor = Colors.grey;
    if (isLeaveType && detailsList.length > 1) {
      final secondDetail = detailsList[1];
      thirdImg = (secondDetail['img_name'] as String?)?.isNotEmpty == true
          ? secondDetail['img_name']
          : 'assets/avatar_placeholder.png';
      thirdBorderColor = _getStatusColor(secondDetail['decide'] ?? '');
    }

    // ----------------------------------------------------------------
    //  BUILD THE ACTUAL WIDGET FLOW
    // ----------------------------------------------------------------
    // Always start with the requestor
    List<Widget> flow = [
      _buildUserAvatar(requestorImg, borderColor: requestorBorderColor),
      buildArrow(),
      _buildUserAvatar(secondImg, borderColor: secondBorderColor),
    ];

    // If it's a leave type, add the second arrow and the third avatar
    if (isLeaveType) {
      flow.add(buildArrow());
      flow.add(_buildUserAvatar(thirdImg, borderColor: thirdBorderColor));
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: flow,
    );
  }

  /// Reusable widget for showing avatar with a colored border
  Widget _buildUserAvatar(String imageUrl, {Color borderColor = Colors.grey}) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: borderColor,
      child: CircleAvatar(
        radius: 22,
        backgroundImage: imageUrl.startsWith('http')
            ? NetworkImage(imageUrl)
            : AssetImage(imageUrl) as ImageProvider,
        onBackgroundImageError: (_, __) {
          // fallback if the image fails to load
        },
        backgroundColor: Colors.grey[300],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final String type = widget.types.toLowerCase();
    final lowerStatus = widget.status.toLowerCase();

    // Hide for "minutes of meeting" type
    if (type == 'minutes of meeting' || lowerStatus == 'approved' || lowerStatus == 'disapproved' || lowerStatus == 'cancel') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        children: [
          Expanded(
            child: _buildStyledButton(
              label: 'Delete',
              icon: Icons.close,
              backgroundColor: Colors.grey,
              textColor: Colors.white,
              onPressed: isFinalized ? null : () => _confirmDelete(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStyledButton(
              label: 'Edit',
              icon: Icons.edit,
              backgroundColor: const Color(0xFFDBB342),
              textColor: Colors.white,
              onPressed: isFinalized ? null : () => _handleEdit(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon inside a circular container
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white, // Circle background color
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: backgroundColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEdit() async {
    setState(() {
      isFinalized = true;
    });

    final String type = widget.types.toLowerCase();
    String idToSend;
    if (type == 'leave') {
      idToSend = data?['take_leave_request_id']?.toString() ?? widget.id;
    } else {
      idToSend = data?['uid']?.toString() ?? widget.id;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficeBookingEventEditPage(
          id: idToSend,
          type: type,
        ),
      ),
    ).then((result) {
      if (kDebugMode) {
        debugPrint('Returned from Edit Page with result: $result');
      }
      if (result == true) {
        _fetchData();
      }
    });

    setState(() {
      isFinalized = false;
    });
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this request?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    final String type = widget.types.toLowerCase();
    final String id = widget.id;
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Request ID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found.');
      return;
    }

    setState(() {
      isFinalized = true;
    });

    try {
      http.Response response;
      switch (type) {
        case 'leave':
          response = await http.put(
            Uri.parse('$baseUrl/api/leave_cancel/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog('Success', 'Leave request deleted.');
          } else {
            _showErrorDialog(
                'Error',
                'Failed to delete leave request: ${response.reasonPhrase}\n'
                    'Response Body: ${response.body}');
          }
          break;

        case 'car':
          response = await http.delete(
            Uri.parse(
                '$baseUrl/api/office-administration/car_permit/${data?["uid"] ?? id}'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog('Success', 'Car permit deleted.');
          } else {
            _showErrorDialog(
                'Error',
                'Failed to delete car permit: ${response.reasonPhrase}\n'
                    'Response Body: ${response.body}');
          }
          break;

        case 'meeting':
          response = await http.delete(
            Uri.parse(
                '$baseUrl/api/office-administration/book_meeting_room/${data?["uid"] ?? id}'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog('Success', 'Meeting deleted.');
          } else {
            _showErrorDialog(
                'Error',
                'Failed to delete meeting: ${response.reasonPhrase}\n'
                    'Response Body: ${response.body}');
          }
          break;

        case 'minutes of meeting':
          _showErrorDialog('Error', 'Delete for minutes of meeting not implemented.');
          break;

        default:
          _showErrorDialog('Error', 'Unknown request type.');
      }
    } catch (e) {
      debugPrint('Error deleting request: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred while deleting the request.');
    }

    setState(() {
      isFinalized = false;
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _defaultAvatarUrl() {
    return 'https://www.w3schools.com/howto/img_avatar.png';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 24.0;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.redAccent : Colors.red,
            ),
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _handleRefresh,
        child: data == null
            ? Center(
          child: Text(
            'No Data Available',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.red,
            ),
          ),
        )
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  _buildRequestorSection(),
                  const SizedBox(height: 8),
                  _buildBlueSection(),
                  const SizedBox(height: 18),
                  _buildDetailsSection(),
                  const SizedBox(height: 14),
                  _buildWorkflowSection(),
                  SizedBox(height: screenHeight * 0.02),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
