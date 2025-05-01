// approvals_details_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approvals_page/comment_approvals_reply.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApprovalsDetailsPage extends StatefulWidget {
  final String id;
  final String type;

  const ApprovalsDetailsPage({
    super.key,
    required this.id,
    required this.type,
  });

  @override
  ApprovalsDetailsPageState createState() => ApprovalsDetailsPageState();
}

class ApprovalsDetailsPageState extends State<ApprovalsDetailsPage> {
  final TextEditingController _descriptionController = TextEditingController();

  /// A separate controller for the reason typed in the bottom sheet
  final TextEditingController _rejectReasonController = TextEditingController();
  final TextEditingController _approveReasonController =
      TextEditingController();

  bool isLoading = true;
  bool isFinalized = false;
  Map<String, dynamic>? approvalData;
  String? requestorImage;
  List<Map<String, dynamic>> _fetchedVehicles = [];
  String? _selectedVehicleUid;
  bool _isFetchingVehicles = false;
  List<Map<String, dynamic>> _waitingList = [];
  bool _isFetchingWaitingList = false;
  String? _selectedWaitingUid;
  String? _selectedMergeVehicleUid;

  String standardErrorMessage =
      'We\'re unable to process your request at the moment. Please contact IT support for assistance.';

  // Base URL for images
  final String _imageBaseUrl =
      'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/';

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _fetchApprovalDetails();
  }

  Future<void> _fetchApprovalDetails() async {
    String apiUrl;

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog(
            'Authentication Error', 'Token not found. Please log out and then log in again.');
        return;
      }

      // Determine the API URL based on the type
      if (widget.type == 'leave') {
        apiUrl = '$baseUrl/api/leave_request/all/${widget.id}';
      } else if (widget.type == 'car') {
        apiUrl = '$baseUrl/api/office-administration/car_permit/${widget.id}';
      } else if (widget.type == 'meeting') {
        apiUrl =
            '$baseUrl/api/office-administration/book_meeting_room/${widget.id}';
      } else {
        throw Exception('Unknown type: ${widget.type}');
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if ((data['statusCode'] == 200 || data['statusCode'] == 201) &&
            data['results'] != null) {
          setState(() {
            approvalData = widget.type == 'leave'
                ? Map<String, dynamic>.from(data['results'][0])
                : Map<String, dynamic>.from(data['results']);

            if (widget.type == 'leave') {
              final employeeId = approvalData?['employee_id'] ??
                  approvalData?['requestor_id'] ??
                  '';
              if (employeeId.isNotEmpty) {
                // Fetch the profile image using the employee_id
                _fetchProfileImage(employeeId).then((imageUrl) {
                  setState(() {
                    requestorImage = imageUrl;
                    isLoading = false;
                  });
                });
              } else {
                requestorImage = 'https://via.placeholder.com/150';
                isLoading = false;
              }
            } else if (widget.type == 'car' || widget.type == 'meeting') {
              final imgName = approvalData?['img_name']?.toString().trim();
              if (imgName != null && imgName.isNotEmpty) {
                // Determine if imgName is a full URL or just an image name
                if (imgName.startsWith('http')) {
                  requestorImage = imgName;
                } else {
                  requestorImage = '$_imageBaseUrl$imgName';
                }
              } else {
                requestorImage = 'https://via.placeholder.com/150';
              }
              isLoading = false;
            }
          });
          debugPrint('Approval details loaded successfully.');
        } else {
          throw Exception(
              standardErrorMessage);
        }
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden: $standardErrorMessage');
      } else if (response.statusCode == 404) {
        throw Exception('Approval details not found: $standardErrorMessage');
      } else {
        throw Exception(
            'Failed to load approval details: $standardErrorMessage');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching approval details: $e');
      debugPrint(stackTrace.toString());
      _showErrorDialog('Error', standardErrorMessage);
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _handleMerge(BuildContext context) async {
    final String? token = await _getToken();
    if (token == null) {
      _showErrorDialog(
          'Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    final String endpoint =
        '$baseUrl/api/office-administration/car_permit/approved/merge/${widget.id}';

    final String? selectedWaitingUid = _selectedWaitingUid;
    final String? selectedVehicleUid = _selectedMergeVehicleUid;

    if (selectedWaitingUid == null || selectedVehicleUid == null) {
      _showErrorDialog('Error', 'Please select both options.');
      return;
    }

    final Map<String, dynamic> body = {
      "merges": [
        {
          "topic_uid": selectedWaitingUid,
        }
      ],
      "vehicle_id": selectedVehicleUid,
    };

    setState(() {
      isFinalized = true;
    });

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('[Merge] Status: ${response.statusCode}');
      debugPrint('[Merge] Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        _showSuccessDialog(
            'Success', 'Car permits have been merged successfully.');
        // Optionally, refresh the approval details
        _fetchApprovalDetails();
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'Failed to merge car permits.';
        _showErrorDialog('Error', standardErrorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('Error merging car permits: $e');
      debugPrint(stackTrace.toString());
      _showErrorDialog('Error', standardErrorMessage);
    } finally {
      setState(() {
        isFinalized = false;
      });
    }
  }

  Future<void> _fetchWaitingList() async {
    setState(() {
      _isFetchingWaitingList = true;
    });

    final String apiUrl =
        '$baseUrl/api/office-administration/car_permits/waiting/merge/${widget.id}';

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog(
            'Authentication Error', 'Token not found. Please log in again.');
        return;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Fetch Waiting List Status Code: ${response.statusCode}');
      debugPrint('Fetch Waiting List Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] != null) {
          setState(() {
            _waitingList = List<Map<String, dynamic>>.from(data['results']);
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load waiting list.');
        }
      } else {
        throw Exception('Failed to load waiting list');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching waiting list: $standardErrorMessage');
      debugPrint(stackTrace.toString());
      _showErrorDialog('Error', standardErrorMessage);
    } finally {
      setState(() {
        _isFetchingWaitingList = false;
      });
    }
  }

  Future<void> _fetchMyVehicles() async {
    final String? token = await _getToken();
    if (token == null) {
      _showErrorDialog(
          'Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    final String apiUrl = '$baseUrl/api/office-administration/my-vehicles';

    setState(() {
      _isFetchingVehicles = true;
    });

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Fetch Vehicles Status Code: ${response.statusCode}');
      debugPrint('Fetch Vehicles Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] != null) {
          setState(() {
            _fetchedVehicles = List<Map<String, dynamic>>.from(data['results']);
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load vehicles.');
        }
      } else {
        throw Exception('Failed to load vehicles');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching vehicles: $e');
      debugPrint(stackTrace.toString());
      _showErrorDialog('Error', standardErrorMessage);
    } finally {
      setState(() {
        _isFetchingVehicles = false;
      });
    }
  }

  Future<String> _fetchProfileImage(String id) async {
    final String apiUrl = '$baseUrl/api/profile/$id';

    try {
      final String? token = await _getToken();
      if (token == null) {
        throw Exception('Authentication Error: Token not found. Please log out and then log in again');
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] != null) {
          return data['results']['images'] ?? 'https://via.placeholder.com/150';
        } else {
          throw Exception(standardErrorMessage);
        }
      } else {
        throw Exception(standardErrorMessage);
      }
    } catch (e) {
      // Log the error or handle it as per your requirement
      debugPrint('Error fetching profile image: $e');
      return 'https://via.placeholder.com/150'; // Fallback image
    }
  }

  /// Utility to check if status is "Waiting"/"Pending"/"Processing"/etc.
  bool isPendingStatus(String status) {
    return status.toLowerCase() == 'waiting' ||
        status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'processing' ||
        status.toLowerCase() == 'branch waiting' ||
        status.toLowerCase() == 'branch processing' ||
        status.toLowerCase() == 'waiting for approval';
  }

  /// Format date string for display
  String formatDate(String? dateStr, {bool includeDay = false}) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      DateTime parsedDate;

      if (dateStr.contains('T')) {
        parsedDate = DateTime.parse(dateStr);
      } else if (RegExp(r"^\d{4}-\d{1,2}-\d{1,2}$").hasMatch(dateStr)) {
        List<String> dateParts = dateStr.split('-');
        int year = int.parse(dateParts[0]);
        int month = int.parse(dateParts[1]);
        int day = int.parse(dateParts[2]);
        parsedDate = DateTime(year, month, day);
      } else {
        parsedDate = DateTime.parse(dateStr);
      }

      if (includeDay) {
        final dayOfWeek = DateFormat('EEEE').format(parsedDate);
        final dateFormatted = DateFormat('dd-MM-yyyy').format(parsedDate);
        return '$dayOfWeek ($dateFormatted)';
      } else {
        return DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate);
      }
    } catch (e, stackTrace) {
      debugPrint('Date parsing error for "$dateStr": $e');
      debugPrint(stackTrace.toString());
      return 'Invalid Date';
    }
  }

  /// Retrieve stored token
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e, stackTrace) {
      debugPrint('Error retrieving token: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final status = (approvalData?['status']?.toString() ??
            approvalData?['is_approve']?.toString() ??
            'Pending')
        .trim();

    return Scaffold(
      appBar: _buildAppBar(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(26.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  _buildRequestorSection(isDarkMode),
                  const SizedBox(height: 4),
                  _buildBlueSection(isDarkMode),
                  const SizedBox(height: 24),
                  _buildDetailsSection(),

                  // Show comment input & action buttons only for 'leave'/'meeting'
                  if (widget.type == 'leave' || widget.type == 'meeting') ...[
                    const SizedBox(height: 4),
                    if (isPendingStatus(status)) ...[
                      const SizedBox(height: 8),
                      _buildCommentInputSection(),
                      const SizedBox(height: 22),
                      _buildActionButtons(context),
                    ],
                    if (!isPendingStatus(status) &&
                        status.toLowerCase() == 'reject')
                      _buildDenyReasonSection(),
                  ],
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode ? 'assets/darkbg.png' : 'assets/background.png',
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
        'Approvals',
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 24,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: isDarkMode ? Colors.white : Colors.black,
          size: 24,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      toolbarHeight: 90,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildRequestorSection(bool isDarkMode) {
    final requestorName = approvalData?['employee_name'] ??
        approvalData?['requestor_name'] ??
        'No Name';

    String submittedOn = 'N/A';

    if (widget.type == 'meeting' &&
        approvalData?['date_create'] != null &&
        approvalData!['date_create'].toString().isNotEmpty) {
      submittedOn = formatDate(approvalData!['date_create']);
    } else if ((widget.type == 'car' || widget.type == 'else') &&
        approvalData?['updated_at'] != null &&
        approvalData!['updated_at'].toString().isNotEmpty) {
      submittedOn = formatDate(approvalData!['updated_at']);
    } else if (approvalData?['created_at'] != null &&
        approvalData!['created_at'].toString().isNotEmpty) {
      submittedOn = formatDate(approvalData!['created_at']);
    }

    final profileImage = requestorImage ??
        'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Requestor',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(profileImage),
              radius: 35,
              backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              onBackgroundImageError: (error, stackTrace) {
                setState(() {
                  requestorImage = 'https://via.placeholder.com/150';
                });
              },
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requestorName,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Submitted on $submittedOn',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlueSection(bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.7,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blue : Colors.lightBlue[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          _getTypeHeader(),
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

  String _getTypeHeader() {
    if (widget.type == 'leave') {
      return 'Leave';
    } else if (widget.type == 'car') {
      return 'Booking Car';
    } else if (widget.type == 'meeting') {
      return 'Booking Meeting Room';
    } else {
      return 'Approval Details';
    }
  }

  Widget _buildDetailsSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (widget.type == 'leave') {
      return _buildLeaveDetails();
    } else if (widget.type == 'car') {
      return _buildCarDetails();
    } else if (widget.type == 'meeting') {
      return _buildMeetingDetails();
    } else {
      return Center(
        child: Text(
          'Unknown Request Type',
          style: TextStyle(
            fontSize: 18,
            color: isDarkMode ? Colors.white : Colors.red,
          ),
        ),
      );
    }
  }

  /// LEAVE DETAILS
  Widget _buildLeaveDetails() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final status = approvalData?['status']?.toString() ?? 'Pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          'Leave Request ID',
          approvalData?['take_leave_request_id']?.toString() ?? 'N/A',
          Icons.assignment,
          Colors.green,
          isDarkMode,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          'Leave Type',
          approvalData?['name'] ?? 'N/A',
          Icons.person,
          Colors.purple,
          isDarkMode,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          'Reason',
          approvalData?['take_leave_reason'] ?? 'N/A',
          Icons.book,
          Colors.blue,
          isDarkMode,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          'From Date',
          formatDate(approvalData?['take_leave_from'], includeDay: true),
          Icons.calendar_today,
          Colors.blue,
          isDarkMode,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          'Until Date',
          formatDate(approvalData?['take_leave_to'], includeDay: true),
          Icons.calendar_today,
          Colors.blue,
          isDarkMode,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          'Days',
          approvalData?['days']?.toString() ?? 'N/A',
          Icons.today,
          Colors.orange,
          isDarkMode,
        ),
      ],
    );
  }

  /// CAR DETAILS
  Widget _buildCarDetails() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Show them only if status is NOT "Approved", "Rejected", or "Deleted".
    final currentStatus =
        approvalData?['status']?.toString().toLowerCase() ?? '';
    final canShowButtons = (currentStatus != 'approved' &&
        currentStatus != 'disapproved' &&
        currentStatus != 'deleted' &&
        currentStatus != 'completed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          'Car Booking ID',
          approvalData?['id']?.toString() ?? 'N/A',
          Icons.directions_car,
          Colors.green,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          'Purpose',
          approvalData?['purpose'] ?? 'N/A',
          Icons.bookmark,
          Colors.green,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          'Date Out',
          formatDate(approvalData?['date_out'], includeDay: true),
          Icons.calendar_today,
          Colors.blue,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          'Date In',
          formatDate(approvalData?['date_in'], includeDay: true),
          Icons.calendar_today,
          Colors.blue,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          'Status',
          approvalData?['status']?.toString() ?? 'Pending',
          Icons.stairs,
          Colors.red,
          isDarkMode,
        ),

        // If status is not Approved/Rejected/Deleted, show 4 buttons
        if (canShowButtons) ...[
          const SizedBox(height: 60),
          _buildCarActionButtons(isDarkMode),
        ],
      ],
    );
  }

  /// 4 CAR BUTTONS
  Widget _buildCarActionButtons(bool isDarkMode) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // First row: Merge + Reply
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCarButton(
              label: 'Merge',
              backgroundColor: const Color(0xFF4CAF50),
              icon: Icons.description,
              onPressed: () {
                _openMergeBottomSheet(context);
              },
            ),
            _buildCarButton(
              label: 'Reply',
              backgroundColor: const Color(0xFF2196F3),
              icon: Icons.reply,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (ctx) {
                    return FractionallySizedBox(
                      heightFactor: 0.8,
                      child: ChatCommentApprovalSection(id: widget.id),
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Second row: Reject + Approve
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCarButton(
              label: 'Reject',
              backgroundColor: const Color(0xFF9E9E9E),
              icon: Icons.close_rounded,
              onPressed: () => _openRejectBottomSheet(context),
            ),
            _buildCarButton(
              label: 'Approve',
              backgroundColor: const Color(0xFFDBB342),
              icon: Icons.check_circle,
              onPressed: () => _openApproveBottomSheet(context),
            ),
          ],
        ),
      ],
    );
  }

  /// A helper for building a single Car button
  Widget _buildCarButton({
    required String label,
    required Color backgroundColor,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 140,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.2),
        ),
        icon: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  void _openMergeBottomSheet(BuildContext context) async {
    // Clear previous selections
    setState(() {
      _selectedWaitingUid = null;
      _selectedMergeVehicleUid = null;
    });

    // Fetch waiting list and vehicles before showing the bottom sheet
    await _fetchWaitingList();
    await _fetchMyVehicles();

    // Show bottom sheet after data is fetched
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        return Container(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.8,
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: mediaQuery.viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              // Validation Check
              bool isFormValid = _selectedWaitingUid != null &&
                  _selectedMergeVehicleUid != null;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    const Text(
                      'Merge Car Permits',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // First Dropdown - Waiting List
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Waiting Permit *',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isFetchingWaitingList
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                            isExpanded: true,
                            menuMaxHeight: 300,
                            value: _selectedWaitingUid,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[700]
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            hint: const Text('Select Waiting Permit'),
                            items: _waitingList
                                .map<DropdownMenuItem<String>>((item) {
                              String displayText =
                                  '${item['requestor_name']} (${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(item['created_date']))} - ...)';
                              return DropdownMenuItem<String>(
                                value: item['uid'] as String,
                                child: Text(displayText,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedWaitingUid = value;
                                isFormValid = _selectedWaitingUid != null &&
                                    _selectedMergeVehicleUid != null;
                              });
                            },
                          ),
                    const SizedBox(height: 20),

                    // Second Dropdown - Company Vehicle
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Company Vehicle *',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isFetchingVehicles
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                            isExpanded: true,
                            menuMaxHeight: 300,
                            value: _selectedMergeVehicleUid,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[700]
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            hint: const Text('Select Company Vehicle'),
                            items: _fetchedVehicles
                                .map<DropdownMenuItem<String>>((vehicle) {
                              String displayText =
                                  '${vehicle['branch_name']} (${vehicle['brand_name']} - ${vehicle['model_name']} - ${vehicle['province_name']})';
                              return DropdownMenuItem<String>(
                                value: vehicle['uid'] as String,
                                child: Text(displayText,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedMergeVehicleUid = value;
                                isFormValid = _selectedWaitingUid != null &&
                                    _selectedMergeVehicleUid != null;
                              });
                            },
                          ),
                    const SizedBox(height: 30),

                    // Save & Approve Button (Center)
                    Center(
                      child: ElevatedButton(
                        onPressed: isFormValid
                            ? () {
                                Navigator.of(ctx).pop();
                                _showConfirmMergeDialog(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFormValid
                              ? const Color(0xFFDBB342)
                              : Colors.grey, // Disabled state
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 14),
                        ),
                        child: const Text(
                          'Save & Approve',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom)
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

// Confirmation Dialog for Merge
  Future<void> _showConfirmMergeDialog(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning Icon (Centered)
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 80,
                      color: Color(0xFFE2BD30),
                    ),
                    const SizedBox(height: 20),

                    // Text "Confirm Merge"
                    Text(
                      'Confirm Merge',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel Button (Left)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8F9BB3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Confirm Button (Right)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _handleMerge(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE2BD30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // X Button (Top Right)
              Positioned(
                top: 15,
                right: 10,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openApproveBottomSheet(BuildContext context) async {
    // Fetch vehicles BEFORE showing the bottom sheet
    await _fetchMyVehicles();

    _approveReasonController.clear();

    // Show bottom sheet after data is available
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return _isFetchingVehicles
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // Title
                        const Text(
                          'Select Company Vehicle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Vehicle List
                        _fetchedVehicles.isNotEmpty
                            ? Expanded(
                                child: ListView.builder(
                                  itemCount: _fetchedVehicles.length,
                                  itemBuilder: (context, index) {
                                    final vehicle = _fetchedVehicles[index];
                                    final displayText =
                                        '${vehicle['branch_name']} (${vehicle['brand_name']} - ${vehicle['model_name']} - ${vehicle['province_name']})';
                                    return RadioListTile<String>(
                                      title: Text(displayText),
                                      value: vehicle['uid'],
                                      groupValue: _selectedVehicleUid,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedVehicleUid = value;
                                        });
                                      },
                                    );
                                  },
                                ),
                              )
                            : const Text('No vehicles available.'),

                        const SizedBox(height: 20),

                        // Approve Button
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _selectedVehicleUid == null
                                ? null
                                : () {
                                    Navigator.of(ctx).pop();
                                    _showConfirmApproveDialog(context);
                                    _fetchMyVehicles(); // Refetch after approval
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 44, vertical: 12),
                            ),
                            icon: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.check,
                                color: Color(0xFFDBB342),
                                size: 18,
                              ),
                            ),
                            label: const Text(
                              'Approve',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
            },
          ),
        );
      },
    );
  }

  Future<void> _showConfirmApproveDialog(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning Icon (Centered)
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 80,
                      color: Color(0xFFE2BD30),
                    ),
                    const SizedBox(height: 20),

                    // Text "Confirm"
                    Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel Button (Left)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8F9BB3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Confirm Button (Right)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _handleApproveCar(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE2BD30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // X Button (Top Right)
              Positioned(
                top: 15,
                right: 10,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleApproveCar(BuildContext context) async {
    final String? token = await _getToken();
    if (token == null) {
      _showErrorDialog(
          'Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    final String endpoint =
        '$baseUrl/api/office-administration/car_permit/approved/${widget.id}';

    setState(() {
      isFinalized = true;
    });

    final body = {
      "vehicle_id": {
        "vehicle_uid": _selectedVehicleUid ?? "",
      },
      "branch_vehicle": {"vehicle_uid": "", "permit_id": ""}
    };

    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('[Car Approve] Status: ${response.statusCode}');
      debugPrint('[Car Approve] Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Sukses
        _showSuccessDialog('Success', 'Car booking has been approved.');
        // Reset selected vehicle
        setState(() {
          _selectedVehicleUid = null;
        });
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'Failed to approve the car booking.';
        _showErrorDialog('Error', standardErrorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('Error approving car: $e');
      debugPrint(stackTrace.toString());
      _showErrorDialog(
          'Error', 'An unexpected error occurred while approving.');
    } finally {
      setState(() {
        isFinalized = false;
      });
    }
  }

  /// Show a bottom sheet that slides up with a reason text field + Reject button
  void _openRejectBottomSheet(BuildContext context) {
    _rejectReasonController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: mediaQuery.viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon + Title
              const Icon(Icons.question_answer,
                  size: 52, color: Color(0xFFDBB342)),
              const SizedBox(height: 6),
              const Text(
                'Reason',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // Text Field
              TextField(
                controller: _rejectReasonController,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Reason for reject',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reject button
              SizedBox(
                width: 130,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDB5E42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showConfirmRejectDialog(context);
                  },
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showConfirmRejectDialog(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning Icon (Centered)
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 80,
                      color: Color(0xFFE2BD30),
                    ),
                    const SizedBox(height: 20),

                    // Text "Confirm"
                    Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel Button (Left)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8F9BB3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Confirm Button (Right)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _handleCarReject(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE2BD30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // X Button (Top Right)
              Positioned(
                top: 15,
                right: 10,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Actually call the disapprove API for the car
  Future<void> _handleCarReject(BuildContext context) async {
    final String? token = await _getToken();
    if (token == null) {
      _showErrorDialog(
          'Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    final endpoint =
        '$baseUrl/api/office-administration/car_permit/disapproved/${widget.id}';
    final reason = _rejectReasonController.text.trim();

    setState(() {
      isFinalized = true;
    });

    try {
      // Build the request body hanya jika alasan diisi
      final requestBody = reason.isNotEmpty ? {"comment": reason} : {};

      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('[Car Reject] Status: ${response.statusCode}');
      debugPrint('[Car Reject] Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Sukses
        _showSuccessDialog('Rejected', 'Car booking has been rejected.');
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'Failed to reject the car booking.';
        _showErrorDialog('Error', standardErrorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('Error rejecting car: $e');
      debugPrint(stackTrace.toString());
      _showErrorDialog(
          'Error', standardErrorMessage);
    } finally {
      setState(() {
        isFinalized = false;
      });
    }
  }

  /// MEETING DETAILS
  Widget _buildMeetingDetails() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          'Meeting ID',
          approvalData?['meeting_id']?.toString() ?? 'N/A',
          Icons.meeting_room,
          Colors.green,
          isDarkMode,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Title',
          approvalData?['title'] ?? 'N/A',
          Icons.title,
          Colors.blue,
          isDarkMode,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'From Date',
          formatDate(approvalData?['from_date_time'], includeDay: true),
          Icons.calendar_today,
          Colors.blue,
          isDarkMode,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'To Date',
          formatDate(approvalData?['to_date_time'], includeDay: true),
          Icons.calendar_today,
          Colors.blue,
          isDarkMode,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Room Name',
          approvalData?['room_name']?.toString() ?? 'N/A',
          Icons.room,
          Colors.orange,
          isDarkMode,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Status',
          approvalData?['status']?.toString() ?? 'Pending',
          Icons.stairs,
          Colors.red,
          isDarkMode,
        ),
      ],
    );
  }

  /// Common UI row with icon + label + content
  Widget _buildInfoRow(
    String title,
    String content,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// COMMENT INPUT: SHOWN ONLY FOR LEAVE/MEETING
  Widget _buildCommentInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            hintText: 'Enter approval/rejection comments',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  /// DENY REASON: SHOWN ONLY FOR LEAVE/MEETING
  Widget _buildDenyReasonSection() {
    final denyReason =
        approvalData?['deny_reason']?.toString() ?? 'No reason provided.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deny Reason',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            denyReason,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ],
    );
  }

  /// APPROVE/REJECT BUTTONS: SHOWN ONLY FOR LEAVE/MEETING
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStyledButton(
          label: 'Reject',
          icon: Icons.close,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          onPressed: isFinalized ? null : () => _handleReject(context),
        ),
        _buildStyledButton(
          label: 'Approve',
          icon: Icons.check_circle_outline,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          onPressed: isFinalized ? null : () => _handleApprove(context),
        ),
      ],
    );
  }

  Widget _buildStyledButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      icon: Icon(icon, color: textColor, size: 20),
      label: Text(
        label,
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context) async {
    await _sendApprovalStatus('approve', context);
  }

  Future<void> _handleReject(BuildContext context) async {
    await _sendApprovalStatus('reject', context);
  }

  /// Original approval/rejection code for leave/meeting (unchanged)
  Future<void> _sendApprovalStatus(String action, BuildContext context) async {
    final comment = _descriptionController.text.trim();

    setState(() {
      isFinalized = true;
    });

    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String? token = await _getToken();
    if (token == null) {
      _showErrorDialog(
          'Authentication Error', 'Token not found. Please log out and then log in again.');
      setState(() {
        isFinalized = false;
      });
      return;
    }

    String primaryEndpoint = '';
    String fallbackEndpoint = '';
    Map<String, dynamic> body = {};
    String method = 'PUT';

    if (widget.type == 'leave' && action == 'approve') {
      primaryEndpoint = '$baseUrl/api/leave_approve/${widget.id}';
      fallbackEndpoint = '$baseUrl/api/leave_processing/${widget.id}';
    } else if (widget.type == 'leave' && action == 'reject') {
      primaryEndpoint = '$baseUrl/api/leave_reject/${widget.id}';
    } else if (widget.type == 'meeting') {
      if (action == 'approve') {
        primaryEndpoint =
            '$baseUrl/api/office-administration/book_meeting_room/approve/${widget.id}';
      } else if (action == 'reject') {
        primaryEndpoint =
            '$baseUrl/api/office-administration/book_meeting_room/disapprove/${widget.id}';
      }
    } else if (widget.type == 'car') {
      method = 'POST';
      primaryEndpoint = '$baseUrl/api/app/tasks/approvals/pending/${widget.id}';
      body = {
        "status": action == 'approve' ? 'Approved' : 'Rejected',
        "types": widget.type,
      };
    } else {
      _showErrorDialog('Error', 'Invalid request type. Please contact IT support for assistance.');
      setState(() {
        isFinalized = false;
      });
      return;
    }

    if (comment.isNotEmpty) {
      body['comments'] = comment;
    }

    debugPrint('Sending $action request to $primaryEndpoint');

    // Function to handle the API call
    Future<String?> callApi(String endpoint) async {
      try {
        http.Response response;
        if (method == 'PUT') {
          response = await http.put(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
        } else {
          response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
        }

        debugPrint('API response status: ${response.statusCode}');
        debugPrint('API response body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          return null; // Success, no error message
        } else {
          final responseBody = jsonDecode(response.body);
          return responseBody['message'] ?? 'Unknown error occurred.';
        }
      } catch (e, stackTrace) {
        debugPrint('Error calling API: $e');
        debugPrint(stackTrace.toString());
        return 'An unexpected error occurred while connecting to the server.';
      }
    }

    // Attempt primary API call
    String? errorMessage = await callApi(primaryEndpoint);

    // If primary fails, try fallback
    if (errorMessage != null && fallbackEndpoint.isNotEmpty) {
      debugPrint('Primary API failed, trying fallback API...');
      errorMessage = await callApi(fallbackEndpoint);
    }

    // Show result
    if (errorMessage == null) {
      _showSuccessDialog('Success', 'Request has been $action successfully.');
    } else {
      _showErrorDialog('Error', standardErrorMessage);
    }

    setState(() {
      isFinalized = false;
    });
  }

  /// Generic error dialog
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

  /// Generic success dialog
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(); // Navigate back
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
