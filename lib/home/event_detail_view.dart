// event_detail_view.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../settings/theme_notifier.dart';

/// Entry point for the Event Detail View.
class EventDetailView extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailView({super.key, required this.event});

  @override
  EventDetailViewState createState() => EventDetailViewState();
}

class EventDetailViewState extends State<EventDetailView> with SingleTickerProviderStateMixin {
  // State variables
  bool _isLoading = false;
  bool _hasResponded = false;
  bool _joined = false;
  bool _rejected = false;
  bool _maybe = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late String _eventType;
  late String eventStatus;
  late String autoLanguageType;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkUserResponse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _determineEventType();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Determines the type of event based on its category.
  void _determineEventType() {
    _eventType = widget.event['category'];
    eventStatus = widget.event['status'];
    switch (_eventType) {
      case 'Add Meeting':
        autoLanguageType = AppLocalizations.of(context)!.meetingTitle;
      case 'Leave':
        autoLanguageType = AppLocalizations.of(context)!.leave;
      case 'Meeting Room Bookings':
        autoLanguageType = AppLocalizations.of(context)!.meetingRoomBookings;
      case 'Booking Car':
        autoLanguageType = AppLocalizations.of(context)!.bookingCar;
      case 'Minutes Of Meeting':
        autoLanguageType = AppLocalizations.of(context)!.minutesOfMeeting;
      default:
        autoLanguageType = AppLocalizations.of(context)!.other;
    }
  }

  /// Initializes the animation controller and animations.
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  /// Checks if the user has already responded to the event.
  Future<void> _checkUserResponse() async {
    final prefs = await SharedPreferences.getInstance();
    final responses = prefs.getStringList('eventResponses') ?? [];
    final uid = widget.event['uid'] ?? widget.event['outmeeting_uid'] ?? '';

    final response = responses.firstWhere(
      (resp) {
        final parts = resp.split(':');
        return parts.length == 2 && parts[0] == uid;
      },
      orElse: () => '',
    );

    if (response.isNotEmpty) {
      final answer = response.split(':');
      final detectStatus = answer[1];
      switch (detectStatus) {
        case 'no':
          _rejected = true;
        case 'yes':
          _joined = true;
        case 'maybe':
          _maybe = true;
        default:
          debugPrint("Can't detect the answer");
      }
      setState(() {
        _hasResponded = false;
      });
    } else {
      setState(() {
        _hasResponded = true;
      });
    }
  }

  /// Handles the user response to the meeting event.
  Future<void> _respondToMeeting(String responseType) async {
    if (_hasResponded) return;

    if (responseType == 'no' || responseType == 'maybe') {
      bool confirmed = await _showConfirmationDialog(responseType);
      if (!confirmed) return;
    }

    setState(() {
      _isLoading = true;
    });

    final uid = widget.event['uid'] ?? widget.event['outmeeting_uid'] ?? '';
    const baseUrl = 'https://demo-application-api.flexiflows.co';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      showSnackBarEvent(
        'Authentication Error. Please log in again.',
        Colors.red,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    String endpoint;
    String successMessage;
    Color snackBarColor;

    // Only 'Meeting' events have response functionality
    if (_eventType == 'Add Meeting') {
      switch (responseType) {
        case 'yes':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/yes/$uid';
          successMessage = 'Successfully joined the meeting.';
          snackBarColor = Colors.green;
          break;
        case 'no':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/no/$uid';
          successMessage = 'You have rejected the meeting.';
          snackBarColor = Colors.red;
          break;
        case 'maybe':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/maybe/$uid';
          successMessage = 'You have marked your response as Maybe.';
          snackBarColor = Colors.orange;
          break;
        default:
          showSnackBarEvent('Invalid response type.', Colors.red);
          setState(() {
            _isLoading = false;
          });
          return;
      }
    } else if (_eventType == 'Booking Car') {
      switch (responseType) {
        case 'yes':
          endpoint = '/api/office-administration/car_permit/yes/$uid';
          successMessage = 'Successfully joined the booking car.';
          snackBarColor = Colors.green;
          break;
        case 'no':
          endpoint = '/api/office-administration/car_permit/no/$uid';
          successMessage = 'You have rejected the booking car.';
          snackBarColor = Colors.red;
          break;
        default:
          showSnackBarEvent('Invalid response type.', Colors.red);
          setState(() {
            _isLoading = false;
          });
          return;
      }
    } else if (_eventType == 'Meeting Room Bookings') {
      switch (responseType) {
        case 'yes':
          endpoint = '/api/office-administration/book_meeting_room/yes/$uid';
          successMessage = 'Successfully joined the meeting.';
          snackBarColor = Colors.green;
          break;
        case 'no':
          endpoint = '/api/office-administration/book_meeting_room/no/$uid';
          successMessage = 'You have rejected the meeting.';
          snackBarColor = Colors.red;
          break;
        case 'maybe':
          endpoint = '/api/office-administration/book_meeting_room/maybe/$uid';
          successMessage = 'You have marked your response as Maybe.';
          snackBarColor = Colors.orange;
          break;
        default:
          showSnackBarEvent('Invalid response type.', Colors.red);
          setState(() {
            _isLoading = false;
          });
          return;
      }
    } else {
      // For other event types, responding is not supported
      showSnackBarEvent(
        'Responding to this event type is not supported.',
        Colors.red,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final url = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await http.put(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if ([200, 201, 202].contains(response.statusCode)) {
        setState(() {
          _hasResponded = true;
        });
        // Store the user's response locally
        final responses = prefs.getStringList('eventResponses') ?? [];
        responses.add('$uid:$responseType');
        await prefs.setStringList('eventResponses', responses);
        showSnackBarEvent(successMessage, snackBarColor);
      } else {
        showSnackBarEvent(
          'Failed to respond. Status: ${response.statusCode}',
          Colors.red,
        );
      }
    } catch (error) {
      showSnackBarEvent('An unexpected error occurred.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Displays a confirmation dialog based on the response type.
  Future<bool> _showConfirmationDialog(String responseType) async {
    String title;
    String content;
    Color dialogColor;

    switch (responseType) {
      case 'no':
        title = 'Reject Meeting';
        content = 'Are you sure you want to reject this meeting?';
        dialogColor = Colors.red;
        break;
      case 'maybe':
        title = 'Maybe Attend';
        content = 'Are you unsure about attending this meeting?';
        dialogColor = Colors.orange;
        break;
      default:
        return true;
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: dialogColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                content,
                style: const TextStyle(color: Colors.black87),
              ),
              actions: [
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dialogColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Formats a given date string into a readable format.
  String _formatDate(String dateStr, {String format = 'dd-MM-yyyy'}) {
    if (dateStr.isEmpty) return '';
    try {
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat(format).format(parsedDate);
    } catch (e) {
      return dateStr; // Return original string if parsing fails
    }
  }

  /// Extracts and formats necessary event details.
  Map<String, String> _getEventDetails() {
    String creatorName = widget.event['createdBy'] ?? widget.event['created_by_name'] ?? widget.event['employee_name'] ?? 'Unknown';
    String imageUrl = widget.event['img_path'] ?? widget.event['img_name'] ?? '';

    // Formatting Created At Date
    String formattedCreatedAt = widget.event['created_at'] != null
        ? _formatDate(widget.event['created_at'].toString(), format: 'dd-MM-yyyy - HH:mm')
        : '';

    // Formatting Start Date & End Date
    String formattedStartDate = widget.event['startDateTime'] != null
        ? _formatDate(widget.event['startDateTime'].toString(), format: 'dd-MM-yyyy')
        : '';

    String formattedEndDate = widget.event['endDateTime'] != null
        ? _formatDate(widget.event['endDateTime'].toString(), format: 'dd-MM-yyyy')
        : '';

    return {
      'creatorName': creatorName,
      'imageUrl': imageUrl,
      'formattedCreatedAt': formattedCreatedAt,
      'formattedStartDate': formattedStartDate,
      'formattedEndDate': formattedEndDate,
    };
  }

  Future<void> _downloadFiles() async {
    if (widget.event['file_name'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files to download')),
      );
      return;
    }

    bool allSuccess = true;

    String fileUrl = widget.event['file_name']?.toString() ?? '';
    String fileName = 'unknown_file';

    if (fileUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid URL for file: $fileName')),
        );
      }
      allSuccess = false;

      try {
        final response = await http.get(Uri.parse(fileUrl));
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$fileName';
        if (response.statusCode == 200) {
          final fileToSave = File(path);
          await fileToSave.writeAsBytes(response.bodyBytes);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to download $fileName')),
            );
          }
          allSuccess = false;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error downloading $fileName: $e')),
          );
        }
        allSuccess = false;
      }
    }

    if (allSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All files downloaded successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Some files failed to download')),
        );
      }
    }
  }

  Widget _buildMembersList(List<dynamic> members) {
    if (members.isEmpty) return const SizedBox.shrink();

    List<Widget> membersList = [];
    Set<String> uniqueMembers = {};

    for (var v in members) {
      if (uniqueMembers.add(v['employee_id'])) {
        membersList.add(_avatarUser(v['img_name'], v['status'] ?? ''));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AppLocalizations.of(context)!.member}:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: GridView.count(
              crossAxisCount: 7,
              children: membersList,
            ),
          ),
          const SizedBox(height: 25),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     Row(
          //       children: [
          //         const Icon(Icons.folder_open),
          //         const SizedBox(
          //           width: 10,
          //         ),
          //         Text(
          //           AppLocalizations.of(context)!.description,
          //           textAlign: TextAlign.left,
          //           style: const TextStyle(
          //             fontSize: 16,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 15),
          // Text(
          //   widget.event['description'],
          // ),
        ],
      ),
    );
  }

  Widget _avatarUser(String link, String? status) {
    Color statusColor;

    switch (status) {
      case 'Pending':
        statusColor = Colors.orange;
      case 'Yes':
        statusColor = Colors.green;
      case 'No':
        statusColor = Colors.red;

      default:
        statusColor = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: statusColor),
        borderRadius: BorderRadius.circular(50),
      ),
      margin: const EdgeInsets.only(right: 3),
      child: CircleAvatar(
          radius: 20,
          backgroundImage: link.isNotEmpty ? NetworkImage(link) : const AssetImage('assets/avatar_placeholder.png') as ImageProvider,
          onBackgroundImageError: (_, __) {
            const AssetImage('assets/avatar_placeholder.png');
          }),
    );
  }

  /// Builds the action buttons (Join, Maybe, Reject).
  Widget _buildActionButtons(double horizontalPadding) {
    Widget statusResult = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reject Button
        Expanded(
          child: _buildResponsiveButton(
            label: AppLocalizations.of(context)!.reject,
            color: _hasResponded ? Colors.grey : Colors.grey,
            onPressed: _hasResponded ? null : () => _respondToMeeting('no'),
            icon: Icons.clear,
          ),
        ),
        const SizedBox(width: 15),

        // Maybe Button
        Visibility(
          visible: _eventType == 'Meeting Room Bookings',
          child: Expanded(
            child: _buildResponsiveButton(
              label: AppLocalizations.of(context)!.maybe,
              color: _hasResponded ? Colors.grey : Colors.orange,
              onPressed: _hasResponded ? null : () => _respondToMeeting('maybe'),
              icon: Icons.question_mark,
            ),
          ),
        ),
        const SizedBox(width: 15),

        // Join Button
        Expanded(
          child: _buildResponsiveButton(
            label: AppLocalizations.of(context)!.join,
            color: _hasResponded ? Colors.grey : ColorStandardization().colorDarkGold,
            onPressed: _hasResponded ? null : () => _respondToMeeting('yes'),
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );

    if (_joined) {
      statusResult = Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(AppLocalizations.of(context)!.joined,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
              )));
    }
    if (_rejected) {
      statusResult = Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(AppLocalizations.of(context)!.rejected,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
              )));
    }
    if (_maybe) {
      statusResult = Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(AppLocalizations.of(context)!.maybe,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
              )));
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 25),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : statusResult,
      ),
    );
  }

  /// Builds a styled ElevatedButton with responsive design.
  Widget _buildResponsiveButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    required IconData icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: onPressed != null ? 6 : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(icon),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  /// Builds the creator section for Meeting events.
  Widget _buildCreatorSection(Map<String, String> details) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            AppLocalizations.of(context)!.requestor,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Row(
          children: [
            CircleAvatar(
                radius: 26,
                backgroundImage: details['imageUrl']!.isNotEmpty ? NetworkImage(details['imageUrl']!) : const AssetImage('assets/avatar_placeholder.png') as ImageProvider,
                onBackgroundImageError: (_, __) {
                  const AssetImage('assets/avatar_placeholder.png');
                }),
            const SizedBox(
              width: 15,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (details['creatorName']?.isEmpty ?? true) ? 'No Name' : details['creatorName']!,
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                  height: 7,
                ),
                if (details['formattedCreatedAt']!.isNotEmpty)
                  Text(
                    '${AppLocalizations.of(context)!.submittedOn} ${details['formattedCreatedAt']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the event type widget.
  Widget _buildEventType() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.greenAccent : Colors.lightBlue.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      width: double.maxFinite,
      child: Text(
        autoLanguageType,
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.black : Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the list of event details.
  Widget _buildMinutesOfMeetingEventDetails() {
    final details = _getEventDetails();
    String? title = widget.event['title'];
    final startDate = DateTime.parse(widget.event['startDateTime']);
    final endDate = DateTime.parse(widget.event['endDateTime']);
    String startDisplay12 = "${(startDate.hour % 12 == 0 ? 12 : startDate.hour % 12).toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')} ${startDate.hour >= 12 ? 'PM' : 'AM'}";
    String endDisplay12 = "${(endDate.hour % 12 == 0 ? 12 : endDate.hour % 12).toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')} ${endDate.hour >= 12 ? 'PM' : 'AM'}";
    return Column(
      children: [
        if (eventStatus != "")
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_add_outlined),
                          SizedBox(width: 10),
                          Text('Title'),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.access_time,
                              color: ColorStandardization().colorDarkGold,
                            ),
                          ),
                          Text(
                            eventStatus,
                            style: TextStyle(
                              color: ColorStandardization().colorDarkGold,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                Text(title ?? ''),
              ],
            ),
          ),
        const SizedBox(height: 20),
        if (details['formattedStartDate']!.isNotEmpty)
          titleCustom(
            'Date : ${startDate.year}-${startDate.month}-${startDate.day} - ${endDate.year}-${endDate.month}-${endDate.day}',
            Icons.free_cancellation_outlined,
          ),
        if (details['formattedEndDate']!.isNotEmpty)
          titleCustom(
            'Time : $startDisplay12 - $endDisplay12',
            Icons.punch_clock_outlined,
          ),
      ],
    );
  }

  /// Builds the list of event details.
  Widget _buildEventDetails() {
    final details = _getEventDetails();
    String? title = widget.event['title'];
    String? location = widget.event['location'];
    String? leaveType = widget.event['leave_type'];
    String? description = widget.event['description']; // Add this line
    final startDate = DateTime.parse(widget.event['startDateTime']);
    final endDate = DateTime.parse(widget.event['endDateTime']);
    String startDisplay12 = "${(startDate.hour % 12 == 0 ? 12 : startDate.hour % 12).toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')} ${startDate.hour >= 12 ? 'PM' : 'AM'}";
    String endDisplay12 = "${(endDate.hour % 12 == 0 ? 12 : endDate.hour % 12).toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')} ${endDate.hour >= 12 ? 'PM' : 'AM'}";
    return Column(
      children: [
        if (title != null)
          titleCustom(
            '${AppLocalizations.of(context)!.title} : ${widget.event['title']}',
            Icons.bookmark_add_outlined,
          ),
        if (details['formattedStartDate']!.isNotEmpty && details['formattedEndDate']!.isNotEmpty)
          titleCustom(
            '${AppLocalizations.of(context)!.date} : '
                '${startDate.day.toString().padLeft(2, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.year} - '
                '${endDate.day.toString().padLeft(2, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.year}',
            Icons.free_cancellation_outlined,
          ),

        if (details['formattedEndDate']!.isNotEmpty)
          titleCustom(
            '${AppLocalizations.of(context)!.time} : $startDisplay12 - $endDisplay12',
            Icons.punch_clock_outlined,
          ),
        if (location != "" && location != null)
          ListTile(
            leading: const SizedBox.shrink(),
            title: Text(
              '${AppLocalizations.of(context)!.location} : $location',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.orange,
              ),
            ),
          ),
        if (leaveType != "" && leaveType != null)
          ListTile(
            leading: const SizedBox.shrink(),
            title: Text(
              '${AppLocalizations.of(context)!.typeOfLeave} : $leaveType',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.orange,
              ),
            ),
          ),
        // Add description section
        if (description != null && description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]!
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[200]
                          : Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds the main content of the Event Detail View.
  Widget _buildContent(BuildContext context) {
    final details = _getEventDetails();
    final isMinutesOfMeeting = _eventType == 'Minutes Of Meeting';
    final isMeeting = _eventType != 'Minutes Of Meeting';
    final members = widget.event['members'] ?? [];
    final size = MediaQuery.sizeOf(context);

    return Container(
      padding: const EdgeInsets.only(top: 50),
      constraints: BoxConstraints(maxWidth: size.width * 0.8),
      child: SingleChildScrollView(
        child: isMinutesOfMeeting
            ? Column(
                children: [
                  const SizedBox(height: 20),
                  _buildMinutesOfMeetingEventDetails(),
                  const SizedBox(height: 20),
                  if (members.isNotEmpty) _buildMembersList(members),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isMeeting) _buildCreatorSection(details),
                  const SizedBox(height: 8),
                  _buildEventType(),
                  const SizedBox(height: 20),
                  _buildEventDetails(),
                  const SizedBox(height: 12),
                  if (members.isNotEmpty) _buildMembersList(members),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double horizontalPadding = MediaQuery.of(context).size.width * 0.07;
    final isHiddenButton = (_eventType == 'Leave' || _eventType == 'Minutes Of Meeting') || eventStatus == 'Pending';
    Provider.of<ThemeNotifier>(context);

    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[50],
      appBar: _buildAppBar(isDarkMode),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _buildAnimatedContent(_buildContent(context)),
            ),
          ),
          if (!isHiddenButton) _buildActionButtons(horizontalPadding),
        ],
      ),
    );
  }

  /// Builds the AppBar with background.png.
  AppBar _buildAppBar(bool isDarkMode) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
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
        autoLanguageType, // 'Event Details' (localized)
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 28,
          fontWeight: FontWeight.bold,
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

  /// Builds animated content with slide and fade transitions.
  Widget _buildAnimatedContent(Widget child) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: child,
      ),
    );
  }

  Widget titleCustom(String name, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        name,
        style: const TextStyle(
          fontSize: 14,
        ),
      ),
      minTileHeight: 0,
    );
  }
}
