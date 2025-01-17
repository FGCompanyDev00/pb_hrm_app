import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_details_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  bool _isPendingSelected = true;
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  Map<int, String> _leaveTypes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  /// Fetches leave types, pending items, and history items from the API
  Future<void> _fetchHistoryData() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String pendingApiUrl = '$baseUrl/api/app/users/history/pending';
    const String historyApiUrl = '$baseUrl/api/app/users/history';
    const String leaveTypesUrl = '$baseUrl/api/leave-types';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      // Fetch Leave Types
      final leaveTypesResponse = await http.get(
        Uri.parse(leaveTypesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (leaveTypesResponse.statusCode == 200) {
        final leaveTypesBody = jsonDecode(leaveTypesResponse.body);
        if (leaveTypesBody['statusCode'] == 200) {
          final List<dynamic> leaveTypesData = leaveTypesBody['results'];
          _leaveTypes = {
            for (var lt in leaveTypesData) lt['leave_type_id']: lt['name']
          };
        } else {
          throw Exception(
              leaveTypesBody['message'] ?? 'Failed to load leave types');
        }
      } else {
        throw Exception(
            'Failed to load leave types: ${leaveTypesResponse.statusCode}');
      }

      // Fetch Pending Items
      final pendingResponse = await http.get(
        Uri.parse(pendingApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Fetch History Items
      final historyResponse = await http.get(
        Uri.parse(historyApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Initialize temporary lists
      final List<Map<String, dynamic>> tempPendingItems = [];
      final List<Map<String, dynamic>> tempHistoryItems = [];

      // Process Pending Response
      if (pendingResponse.statusCode == 200) {
        final responseBody = jsonDecode(pendingResponse.body);
        if (responseBody['statusCode'] == 200) {
          final List<dynamic> pendingData = responseBody['results'];
          // Exclude items with status 'cancel' from pending
          final List<dynamic> filteredPendingData = pendingData.where((item) {
            final status = (item['status'] ?? '').toString().toLowerCase();
            return status != 'cancel';
          }).toList();

          tempPendingItems.addAll(filteredPendingData
              .map((item) => _formatItem(item as Map<String, dynamic>)));
        } else {
          throw Exception(
              responseBody['message'] ?? 'Failed to load pending data');
        }
      } else {
        throw Exception(
            'Failed to load pending data: ${pendingResponse.statusCode}');
      }

      // Process History Response
      if (historyResponse.statusCode == 200) {
        final responseBody = jsonDecode(historyResponse.body);
        if (responseBody['statusCode'] == 200) {
          final List<dynamic> historyData = responseBody['results'];
          // Exclude items with status 'cancel' from history
          final List<dynamic> filteredHistoryData = historyData.where((item) {
            final status = (item['status'] ?? '').toString().toLowerCase();
            return status != 'cancel';
          }).toList();

          tempHistoryItems.addAll(filteredHistoryData
              .map((item) => _formatItem(item as Map<String, dynamic>)));
        } else {
          throw Exception(responseBody['message'] ??
              AppLocalizations.of(context)!.failedToLoadHistoryData);
        }
      } else {
        throw Exception(
            'Failed to load history data: ${historyResponse.statusCode}');
      }

      // Sort the temporary lists by 'updated_at' in descending order
      tempPendingItems.sort((a, b) {
        DateTime aDate =
            a['updated_at'] ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime bDate =
            b['updated_at'] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate); // Descending order
      });

      tempHistoryItems.sort((a, b) {
        DateTime aDate =
            a['updated_at'] ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime bDate =
            b['updated_at'] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate); // Descending order
      });

      // Update State
      setState(() {
        _pendingItems = tempPendingItems;
        _historyItems = tempHistoryItems;
        _isLoading = false;
      });

      debugPrint(
          'Pending items loaded and sorted: ${_pendingItems.length} items.');
      debugPrint(
          'History items loaded and sorted: ${_historyItems.length} items.');
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error fetching data: $e');
      debugPrint(stackTrace.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  /// Formats each item based on its type
  Map<String, dynamic> _formatItem(Map<String, dynamic> item) {
    String type = item['types']?.toLowerCase() ?? 'unknown';

    Map<String, dynamic> formattedItem = {
      'type': type,
      'status': _getItemStatus(type, item),
      'statusColor': _getStatusColor(_getItemStatus(type, item)),
      'icon': _getIconForType(type),
      'iconColor': _getTypeColor(type),
      'updated_at':
      DateTime.tryParse(item['updated_at'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      'img_name': item['img_name'] ??
          'https://via.placeholder.com/150', // Placeholder image
      'img_path': item['img_path'] ?? '',
    };

    switch (type) {
      case 'meeting':
        formattedItem.addAll({
          'title': item['title'] ?? AppLocalizations.of(context)!.noTitle,
          'startDate': item['from_date_time'] ?? '',
          'endDate': item['to_date_time'] ?? '',
          'room':
          item['room_name'] ?? AppLocalizations.of(context)!.noRoomInfo,
          'employee_name': item['employee_name'] ?? 'N/A',
          'id': item['uid']?.toString() ?? '',
          'remark': item['remark'] ?? '',
        });
        break;

      case 'leave':
        int leaveTypeId = item['leave_type_id'] ?? 0;
        String leaveTypeName = _leaveTypes[leaveTypeId] ?? 'Unknown';
        formattedItem.addAll({
          'title': item['name'] ?? 'No Title',
          'startDate': item['take_leave_from'] ?? '',
          'endDate': item['take_leave_to'] ?? '',
          'leave_type': leaveTypeName,
          'employee_name': item['requestor_name'] ?? 'N/A',
          'id': item['take_leave_request_id']?.toString() ?? '',
        });
        break;

      case 'car':
      // Combine date_out/time_out for 'From' and date_in/time_in for 'To'
        String? dateOut = item['date_in'];
        String? timeOut = item['time_out'];
        String startDateTimeStr = '';
        if (dateOut != null && timeOut != null) {
          startDateTimeStr = '$dateOut' 'T' '$timeOut:00';
        }
        String? dateIn = item['date_out'];
        String? timeIn = item['time_in'];
        String endDateTimeStr = '';
        if (dateIn != null && timeIn != null) {
          endDateTimeStr = '$dateIn' 'T' '$timeIn:00';
        }

        formattedItem.addAll({
          'title':
          item['purpose'] ?? AppLocalizations.of(context)!.noPurpose,
          'startDate': startDateTimeStr,
          'endDate': endDateTimeStr,
          'employee_name': item['requestor_name'] ?? 'N/A',
          'id': item['uid']?.toString() ?? '',
        });
        break;

    /// NEW CASE: minutes of meeting
      case 'minutes of meeting':
        formattedItem.addAll({
          'title': item['title'] ?? AppLocalizations.of(context)!.noTitle,
          'startDate': item['fromdate'] ?? '',
          'endDate': item['todate'] ?? '',
          'employee_name':
          item['created_by_name'] ?? 'N/A',
          'id': item['outmeeting_uid']?.toString() ?? '',
          'description': item['description'] ?? '',
          'location': item['location'] ?? '',
          'file_download_url': item['file_name'] ?? '',
        });
        break;

      default:
      // Handle unknown types if necessary
        break;
    }

    return formattedItem;
  }

  String _getItemStatus(String type, Map<String, dynamic> item) {
    return (item['status'] ?? AppLocalizations.of(context)!.waiting)
        .toString()
        .toLowerCase();
  }

  /// Returns color based on status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'public':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'disapproved':
      case 'rejected':
      case 'cancel':
        return Colors.red;
      case 'pending':
      case 'waiting':
      case 'branch waiting':
        return Colors.amber;
      case 'processing':
        return Colors.blue;
      case 'deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Returns color based on type
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Colors.green;
      case 'leave':
        return Colors.orange;
      case 'car':
        return Colors.blue;

    /// NEW: minutes of meeting color
      case 'minutes of meeting':
        return Colors.purple;

      default:
        return Colors.grey;
    }
  }

  /// Returns icon based on type
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.meeting_room;
      case 'leave':
        return Icons.event;
      case 'car':
        return Icons.directions_car;

    /// NEW: minutes of meeting icon
      case 'minutes of meeting':
        return Icons.sticky_note_2;

      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final Size screenSize = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Dashboard()),
              (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        body: Column(
          children: [
            _buildHeader(isDarkMode, screenSize),
            SizedBox(height: screenSize.height * 0.005),
            _buildTabBar(screenSize),
            SizedBox(height: screenSize.height * 0.005),
            _isLoading
                ? const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
                : Expanded(
              child: RefreshIndicator(
                onRefresh:
                _fetchHistoryData, // This function will refresh data
                child: _isPendingSelected
                    ? _pendingItems.isEmpty
                    ? Center(
                  child: Text(
                    AppLocalizations.of(context)!
                        .noPendingItems,
                    style: TextStyle(
                      fontSize: screenSize.width * 0.04,
                    ),
                  ),
                )
                    : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.04,
                    vertical: screenSize.height * 0.008,
                  ),
                  itemCount: _pendingItems.length,
                  itemBuilder: (context, index) {
                    final item = _pendingItems[index];
                    return _buildHistoryCard(
                      context,
                      item,
                      isHistory: false,
                      screenSize: screenSize,
                    );
                  },
                )
                    : _historyItems.isEmpty
                    ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.myHistoryItems,
                    style: TextStyle(
                      fontSize: screenSize.width * 0.04,
                    ),
                  ),
                )
                    : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.04,
                    vertical: screenSize.height * 0.008,
                  ),
                  itemCount: _historyItems.length,
                  itemBuilder: (context, index) {
                    final item = _historyItems[index];
                    return _buildHistoryCard(
                      context,
                      item,
                      isHistory: true,
                      screenSize: screenSize,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the header section with background image and title
  Widget _buildHeader(bool isDarkMode, Size screenSize) {
    return Container(
      height: screenSize.height * 0.17,
      width: double.infinity,
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
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.04,
            vertical: screenSize.height * 0.015,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: screenSize.width * 0.07,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
              Text(
                AppLocalizations.of(context)!.myHistory,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: screenSize.width * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: screenSize.width * 0.12), // Placeholder
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the tab bar for toggling between Pending and History
  Widget _buildTabBar(Size screenSize) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.03,
        vertical: screenSize.height * 0.003,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isPendingSelected = true;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: _isPendingSelected
                      ? (isDarkMode ? Colors.amber[700] : Colors.amber)
                      : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/pending.png',
                      width: screenSize.width * 0.07,
                      height: screenSize.width * 0.07,
                      color: _isPendingSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      AppLocalizations.of(context)!.pending,
                      style: TextStyle(
                        color: _isPendingSelected
                            ? Colors.white
                            : (isDarkMode
                            ? Colors.grey[400]
                            : Colors.grey[600]),
                        fontWeight: FontWeight.bold,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: screenSize.width * 0.002),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isPendingSelected = false;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: !_isPendingSelected
                      ? (isDarkMode ? Colors.amber[700] : Colors.amber)
                      : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/history.png',
                      width: screenSize.width * 0.07,
                      height: screenSize.width * 0.07,
                      color: !_isPendingSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    SizedBox(width: screenSize.width * 0.02),
                    Text(
                      AppLocalizations.of(context)!.history,
                      style: TextStyle(
                        color: !_isPendingSelected
                            ? Colors.white
                            : (isDarkMode
                            ? Colors.grey[400]
                            : Colors.grey[600]),
                        fontWeight: FontWeight.bold,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds each history/pending card
  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item,
      {required bool isHistory, required Size screenSize}) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final String type = item['type'] ?? 'unknown';

    Color titleColor;
    String detailText;
    Color detailTextColor = Colors.grey;
    String detailLabel;
    Color statusColor = _getStatusColor(item['status']);
    Color typeColor = _getTypeColor(type);

    String formatDate(String dateStr) {
      try {
        final DateTime parsedDate = DateTime.parse(dateStr);
        return DateFormat('dd-MM-yyyy HH:mm').format(parsedDate);
      } catch (e) {
        return 'Invalid Date';
      }
    }

    switch (type) {
      case 'meeting':
        titleColor = Colors.green;
        detailLabel = 'Room:';
        detailText = item['room'] ?? 'N/A';
        detailTextColor = Colors.orange;
        break;
      case 'leave':
        titleColor = Colors.orange;
        detailLabel = 'Type:';
        detailText = item['leave_type'] ?? 'N/A';
        detailTextColor = Colors.orange;
        break;
      case 'car':
        titleColor = Colors.blue;
        detailLabel = 'Tel:';
        detailText = item['employee_tel']?.toString() ?? 'No Phone Number';
        detailTextColor = Colors.grey;
        break;

      case 'minutes of meeting':
        titleColor = Colors.purple;
        detailLabel = 'Location:';
        detailText = item['location'] ?? 'No location';
        detailTextColor = Colors.orange;
        break;

      default:
        titleColor = Colors.grey;
        detailLabel = 'Info:';
        detailText = 'N/A';
    }

    String startDate =
    item['startDate'] != null ? formatDate(item['startDate']) : 'N/A';
    String endDate =
    item['endDate'] != null ? formatDate(item['endDate']) : 'N/A';

    return GestureDetector(
      onTap: () {
        // Format the status to match the API format
        String formattedStatus = item['status'] != null
            ? '${item['status'][0].toUpperCase()}${item['status'].substring(1).toLowerCase()}'
            : 'Waiting'; // Default to 'Waiting' if no status exists

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPage(
              types: type,
              id: item['id'] ?? '',
              status: formattedStatus, // Pass the formatted status
            ),
          ),
        );
      },

      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.03),
          side: BorderSide(color: typeColor, width: screenSize.width * 0.001),
        ),
        margin: EdgeInsets.symmetric(vertical: screenSize.height * 0.008),
        child: Stack(
          children: [
            Positioned(
              top: screenSize.height * 0.01,
              bottom: screenSize.height * 0.01,
              left: screenSize.width * 0.001,
              child: Container(
                width: screenSize.width * 0.005,
                color: typeColor,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: screenSize.height * 0.01,
                horizontal: screenSize.width * 0.03,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'],
                        color: typeColor,
                        size: screenSize.width * 0.08,
                      ),
                      SizedBox(height: screenSize.height * 0.003),
                      type == 'minutes of meeting'
                          ? Column(
                        children: [
                          Text(
                            'Minutes',
                            style: TextStyle(
                              color: typeColor,
                              fontSize: screenSize.width * 0.03,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'of Meeting',
                            style: TextStyle(
                              color: typeColor,
                              fontSize: screenSize.width * 0.03,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        type[0].toUpperCase() + type.substring(1),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: screenSize.width * 0.03,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: screenSize.width * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['employee_name'] ?? 'No Name',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: screenSize.width * 0.038,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.005),
                        Text(
                          'From: $startDate',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.grey[700],
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        Text(
                          'To: $endDate',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.grey[700],
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.005),
                        Text(
                          '$detailLabel $detailText',
                          style: TextStyle(
                            color: detailTextColor,
                            fontSize: screenSize.width * 0.03,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.006),
                        Row(
                          children: [
                            Text(
                              'Status : ',
                              style: TextStyle(
                                fontSize: screenSize.width * 0.03,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenSize.width * 0.015,
                                vertical: screenSize.height * 0.003,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(
                                  screenSize.width * 0.02,
                                ),
                              ),
                              child: Text(
                                item['status'].toString().toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenSize.width * 0.03,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  right: screenSize.width * 0.015,
                  bottom: screenSize.height * 0.02,
                ),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(item['img_name']),
                  radius: screenSize.width * 0.06,
                  backgroundColor:
                  isDarkMode ? Colors.grey[700] : Colors.grey[300],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

