import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_details_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:math' show sin, cos;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  bool _isPendingSelected = true;
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  Map<int, String> _leaveTypes = {};
  bool _isLoading = true;
  bool _showContent = false;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Variables to control the number of items displayed
  int _pendingItemsToShow = 15;
  int _historyItemsToShow = 15;
  final int _maxItemsToShow = 40;

  // Scroll controllers to detect when user is near the end
  final ScrollController _pendingScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();

  // Variables to control button visibility
  bool _showPendingViewMoreButton = false;
  bool _showHistoryViewMoreButton = false;

  static const Map<String, IconData> _typeIcons = {
    'meeting': Icons.meeting_room,
    'leave': Icons.event,
    'car': Icons.directions_car,
    'minutes of meeting': Icons.sticky_note_2,
  };

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fetchHistoryData();
    // Add scroll listeners
    _pendingScrollController.addListener(_checkPendingScrollPosition);
    _historyScrollController.addListener(_checkHistoryScrollPosition);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pendingScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  // Check if user has scrolled near the end of pending items
  void _checkPendingScrollPosition() {
    if (_pendingItems.length <= _pendingItemsToShow ||
        _pendingItemsToShow >= _maxItemsToShow) {
      setState(() {
        _showPendingViewMoreButton = false;
      });
      return;
    }

    // Show button when user has scrolled to about 80% of the visible content
    if (_pendingScrollController.position.pixels >
        _pendingScrollController.position.maxScrollExtent * 0.8) {
      if (!_showPendingViewMoreButton) {
        setState(() {
          _showPendingViewMoreButton = true;
        });
      }
    } else {
      if (_showPendingViewMoreButton) {
        setState(() {
          _showPendingViewMoreButton = false;
        });
      }
    }
  }

  // Check if user has scrolled near the end of history items
  void _checkHistoryScrollPosition() {
    if (_historyItems.length <= _historyItemsToShow ||
        _historyItemsToShow >= _maxItemsToShow) {
      setState(() {
        _showHistoryViewMoreButton = false;
      });
      return;
    }

    // Show button when user has scrolled to about 80% of the visible content
    if (_historyScrollController.position.pixels >
        _historyScrollController.position.maxScrollExtent * 0.8) {
      if (!_showHistoryViewMoreButton) {
        setState(() {
          _showHistoryViewMoreButton = true;
        });
      }
    } else {
      if (_showHistoryViewMoreButton) {
        setState(() {
          _showHistoryViewMoreButton = false;
        });
      }
    }
  }

  /// Fetches leave types, pending items, and history items from the API
  Future<void> _fetchHistoryData() async {
    setState(() {
      _isLoading = true;
      _showContent = false;
    });

    final String pendingApiUrl = '$baseUrl/api/app/users/history/pending';
    final String historyApiUrl = '$baseUrl/api/app/users/history';
    final String leaveTypesUrl = '$baseUrl/api/leave-types';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      // Try to load cached data first for immediate display
      final bool hasCachedData = await _loadCachedData();

      // Always fetch fresh data from API in the background
      try {
        await _fetchDataFromApi(
            prefs, token, pendingApiUrl, historyApiUrl, leaveTypesUrl);
      } catch (apiError) {
        debugPrint('Error fetching data from API: $apiError');

        // Only show error if we don't have cached data
        if (!hasCachedData && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching data: $apiError')),
          );

          // If no cache and API failed, show error state
          if (mounted) {
            setState(() {
              _isLoading = false;
              _showContent = true;
            });
          }
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showContent = true;
        });
        debugPrint('Error fetching data: $e');
        debugPrint(stackTrace.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    }
  }

  String _getDisplayType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return 'Add meeting';
      case 'minutes of meeting':
        return 'Add meeting and booking Room';
      case 'car':
        return 'Booking car';
      case 'leave':
        return 'Leave';
      default:
        return type;
    }
  }

  // New method to load cached data from SharedPreferences
  Future<bool> _loadCachedData() async {
    bool hasCachedData = false;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached leave types
      final cachedLeaveTypes = prefs.getString('cached_leave_types');
      if (cachedLeaveTypes != null) {
        final Map<String, dynamic> leaveTypesData =
            jsonDecode(cachedLeaveTypes);
        _leaveTypes = Map<int, String>.from(leaveTypesData
            .map((key, value) => MapEntry(int.parse(key), value.toString())));
        hasCachedData = true;
      }

      // Load cached pending items
      final cachedPendingItems = prefs.getString('cached_pending_items');
      if (cachedPendingItems != null) {
        final List<dynamic> decodedItems = jsonDecode(cachedPendingItems);
        _pendingItems = decodedItems.map<Map<String, dynamic>>((item) {
          // Convert string dates back to DateTime
          final Map<String, dynamic> typedItem =
              Map<String, dynamic>.from(item);
          if (typedItem['updated_at'] != null) {
            typedItem['updated_at'] = DateTime.parse(typedItem['updated_at']);
          }
          return typedItem;
        }).toList();
        hasCachedData = true;
      }

      // Load cached history items
      final cachedHistoryItems = prefs.getString('cached_history_items');
      if (cachedHistoryItems != null) {
        final List<dynamic> decodedItems = jsonDecode(cachedHistoryItems);
        _historyItems = decodedItems.map<Map<String, dynamic>>((item) {
          // Convert string dates back to DateTime
          final Map<String, dynamic> typedItem =
              Map<String, dynamic>.from(item);
          if (typedItem['updated_at'] != null) {
            typedItem['updated_at'] = DateTime.parse(typedItem['updated_at']);
          }
          return typedItem;
        }).toList();
        hasCachedData = true;
      }

      // If we have cached data, update UI immediately
      if (hasCachedData) {
        setState(() {
          _isLoading = false;
          _showContent = true;
        });
        // Start fade in animation after data is loaded
        await Future.delayed(const Duration(milliseconds: 300));
        _fadeController.forward();
      }

      return hasCachedData;
    } catch (e) {
      debugPrint('Error loading cached data: $e');
      // Continue to API fetch if cache loading fails
      return false;
    }
  }

  // New method to fetch data from API and update cache
  Future<void> _fetchDataFromApi(SharedPreferences prefs, String token,
      String pendingApiUrl, String historyApiUrl, String leaveTypesUrl) async {
    try {
      // Fetch Leave Types
      final leaveTypesResponse = await http.get(
        Uri.parse(leaveTypesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Initialize temporary collections
      final Map<int, String> tempLeaveTypes = {};
      final List<Map<String, dynamic>> tempPendingItems = [];
      final List<Map<String, dynamic>> tempHistoryItems = [];

      if (leaveTypesResponse.statusCode == 200) {
        final leaveTypesBody = jsonDecode(leaveTypesResponse.body);
        if (leaveTypesBody['statusCode'] == 200) {
          final List<dynamic> leaveTypesData = leaveTypesBody['results'];
          tempLeaveTypes.addAll(
              {for (var lt in leaveTypesData) lt['leave_type_id']: lt['name']});

          // Convert to serializable format with string keys
          final Map<String, String> serializableLeaveTypes = tempLeaveTypes.map(
            (key, value) => MapEntry(key.toString(), value),
          );

          // Cache leave types
          await prefs.setString(
              'cached_leave_types', jsonEncode(serializableLeaveTypes));
        }
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
        }
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
        }
      }

      // Only continue if we have data and the widget is still mounted
      if (!mounted) return;

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

      // Cache the new data
      final List<dynamic> serializablePendingItems =
          tempPendingItems.map((item) {
        final Map<String, dynamic> serializable =
            Map<String, dynamic>.from(item);
        // Convert DateTime to string for serialization
        if (serializable['updated_at'] != null) {
          serializable['updated_at'] =
              serializable['updated_at'].toIso8601String();
        }
        return serializable;
      }).toList();

      final List<dynamic> serializableHistoryItems =
          tempHistoryItems.map((item) {
        final Map<String, dynamic> serializable =
            Map<String, dynamic>.from(item);
        // Convert DateTime to string for serialization
        if (serializable['updated_at'] != null) {
          serializable['updated_at'] =
              serializable['updated_at'].toIso8601String();
        }
        return serializable;
      }).toList();

      await prefs.setString(
          'cached_pending_items', jsonEncode(serializablePendingItems));
      await prefs.setString(
          'cached_history_items', jsonEncode(serializableHistoryItems));

      // Update State with new data
      if (mounted) {
        setState(() {
          if (tempLeaveTypes.isNotEmpty) _leaveTypes = tempLeaveTypes;
          _pendingItems = tempPendingItems;
          _historyItems = tempHistoryItems;
          _isLoading = false;
          _showContent = true;
        });

        // Ensure animation runs if it hasn't already
        if (!_fadeController.isCompleted) {
          _fadeController.forward();
        }
      }
    } catch (e) {
      debugPrint('Error fetching data from API: $e');
      // If we're still loading (no cached data was available), show error state
      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
          _showContent = true;
        });
      }
    }
  }

  /// Formats each item based on its type
  Map<String, dynamic> _formatItem(Map<String, dynamic> item) {
    String type = item['types']?.toLowerCase() ?? 'unknown';
    String status = _getItemStatus(type, item);

    // Store status color and type color as hex strings instead of MaterialColor objects
    Color statusColorObj = _getStatusColor(status);
    Color typeColorObj = _getTypeColor(type);

    // Convert colors to hex strings for JSON serialization
    String statusColorHex =
        '#${statusColorObj.value.toRadixString(16).padLeft(8, '0')}';
    String typeColorHex =
        '#${typeColorObj.value.toRadixString(16).padLeft(8, '0')}';

    Map<String, dynamic> formattedItem = {
      'type': type,
      'displayType': _getDisplayType(type),
      'status': status,
      'statusColor': statusColorHex, // Store as hex string
      'statusColorValue': statusColorObj.value, // Store as integer value
      'iconColor': typeColorHex, // Store as hex string
      'iconColorValue': typeColorObj.value, // Store as integer value
      'updated_at': DateTime.tryParse(item['updated_at'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      'img_name': item['img_name'] ??
          'https://via.placeholder.com/150', // Placeholder image
      'img_path': item['img_path'] ?? '',
      'iconType': type,
    };

    switch (type) {
      case 'meeting':
        formattedItem.addAll({
          'title': item['title'] ?? AppLocalizations.of(context)!.noTitle,
          'startDate': item['from_date_time'] ?? '',
          'endDate': item['to_date_time'] ?? '',
          'room': item['room_name'] ?? AppLocalizations.of(context)!.noRoomInfo,
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
          'title': item['purpose'] ?? AppLocalizations.of(context)!.noPurpose,
          'startDate': startDateTimeStr,
          'endDate': endDateTimeStr,
          'employee_name': item['requestor_name'] ?? 'N/A',
          'place': item['place'] ?? 'N/A',
          'id': item['uid']?.toString() ?? '',
        });
        break;

      /// NEW CASE: minutes of meeting
      case 'minutes of meeting':
        formattedItem.addAll({
          'title': item['title'] ?? AppLocalizations.of(context)!.noTitle,
          'startDate': item['fromdate'] ?? '',
          'endDate': item['todate'] ?? '',
          'employee_name': item['created_by_name'] ?? 'N/A',
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
      case 'reject':
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
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  Widget _getIconWidgetForType(String type, double size, Color color) {
    if (type.toLowerCase() == 'minutes of meeting') {
      return Image.asset(
        'assets/room.png',
        width: size,
        height: size,
        color: color,
      );
    } else {
      return Icon(
        _getIconForType(type),
        color: color,
        size: size,
      );
    }
  }

  /// Returns icon based on type
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return const IconData(0xe63c, fontFamily: 'MaterialIcons');
      case 'leave':
        return const IconData(0xe616, fontFamily: 'MaterialIcons');
      case 'car':
        return const IconData(0xe1d7, fontFamily: 'MaterialIcons');
      case 'minutes of meeting':
        return const IconData(0xf04b, fontFamily: 'MaterialIcons');
      default:
        return const IconData(0xe88e, fontFamily: 'MaterialIcons');
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
                ? Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // People Icon Animation Container
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Outer rotating circle
                                      TweenAnimationBuilder(
                                        duration: const Duration(seconds: 2),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        builder: (context, value, child) {
                                          return Transform.rotate(
                                            angle: value * 2 * 3.14159,
                                            child: child,
                                          );
                                        },
                                        child: Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDarkMode
                                                  ? Colors.amber[700]!
                                                  : Colors.amber,
                                              width: 2,
                                              strokeAlign:
                                                  BorderSide.strokeAlignOutside,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // People Icon with Pulse Animation
                                      TweenAnimationBuilder(
                                        duration:
                                            const Duration(milliseconds: 1500),
                                        tween: Tween(begin: 0.8, end: 1.0),
                                        builder: (context, value, child) {
                                          return Transform.scale(
                                            scale: value,
                                            child: child,
                                          );
                                        },
                                        child: Icon(
                                          Icons.people_outline,
                                          size: 40,
                                          color: isDarkMode
                                              ? Colors.amber[700]
                                              : Colors.amber[600],
                                        ),
                                      ),
                                      // Animated dots
                                      ...List.generate(
                                        8,
                                        (index) => Positioned(
                                          top: 35 +
                                              25 * sin(index * 3.14159 / 4),
                                          left: 35 +
                                              25 * cos(index * 3.14159 / 4),
                                          child: TweenAnimationBuilder(
                                            duration: Duration(
                                                milliseconds:
                                                    1000 + index * 100),
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            builder: (context, value, child) {
                                              return Transform.scale(
                                                scale: value,
                                                child: Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: isDarkMode
                                                        ? Colors.amber[700]
                                                            ?.withOpacity(value)
                                                        : Colors.amber[600]
                                                            ?.withOpacity(
                                                                value),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ).toList(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Loading Text with Shimmer Effect
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      isDarkMode
                                          ? Colors.grey[300]!
                                          : Colors.grey[800]!,
                                      isDarkMode
                                          ? Colors.grey[500]!
                                          : Colors.grey[600]!,
                                      isDarkMode
                                          ? Colors.grey[300]!
                                          : Colors.grey[800]!,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    tileMode: TileMode.mirror,
                                  ).createShader(bounds),
                                  child: Text(
                                    'Fetching History Data',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please wait a moment...',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Progress Dots
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    3,
                                    (index) => TweenAnimationBuilder(
                                      duration: Duration(
                                          milliseconds: 400 + (index * 200)),
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? Colors.amber[700]
                                                  : Colors.amber[600],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Expanded(
                    child: AnimatedOpacity(
                      opacity: _showContent ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      child: RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: _isPendingSelected
                            ? _pendingItems.isEmpty
                                ? _buildEmptyState(
                                    AppLocalizations.of(context)!
                                        .noPendingItems,
                                    screenSize,
                                    isDarkMode,
                                  )
                                : Stack(
                                    children: [
                                      ListView.builder(
                                        controller: _pendingScrollController,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenSize.width * 0.04,
                                          vertical: screenSize.height * 0.008,
                                        ),
                                        itemCount: _pendingItems.length >
                                                _pendingItemsToShow
                                            ? _pendingItemsToShow
                                            : _pendingItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _pendingItems[index];
                                          return AnimatedBuilder(
                                            animation: _fadeAnimation,
                                            builder: (context, child) {
                                              return Transform.translate(
                                                offset: Offset(
                                                  0.0,
                                                  (1 - _fadeAnimation.value) *
                                                      20,
                                                ),
                                                child: Opacity(
                                                  opacity: _fadeAnimation.value,
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: _buildHistoryCard(
                                              context,
                                              item,
                                              isHistory: false,
                                              screenSize: screenSize,
                                            ),
                                          );
                                        },
                                      ),
                                      if (_showPendingViewMoreButton)
                                        _buildViewMoreButtonPosition(),
                                    ],
                                  )
                            : _historyItems.isEmpty
                                ? _buildEmptyState(
                                    AppLocalizations.of(context)!
                                        .myHistoryItems,
                                    screenSize,
                                    isDarkMode,
                                  )
                                : Stack(
                                    children: [
                                      ListView.builder(
                                        controller: _historyScrollController,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenSize.width * 0.04,
                                          vertical: screenSize.height * 0.008,
                                        ),
                                        itemCount: _historyItems.length >
                                                _historyItemsToShow
                                            ? _historyItemsToShow
                                            : _historyItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _historyItems[index];
                                          return AnimatedBuilder(
                                            animation: _fadeAnimation,
                                            builder: (context, child) {
                                              return Transform.translate(
                                                offset: Offset(
                                                  0.0,
                                                  (1 - _fadeAnimation.value) *
                                                      20,
                                                ),
                                                child: Opacity(
                                                  opacity: _fadeAnimation.value,
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: _buildHistoryCard(
                                              context,
                                              item,
                                              isHistory: true,
                                              screenSize: screenSize,
                                            ),
                                          );
                                        },
                                      ),
                                      if (_showHistoryViewMoreButton)
                                        _buildViewMoreButtonPosition(),
                                    ],
                                  ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, Size screenSize, bool isDarkMode) {
    return Center(
      child: AnimatedOpacity(
        opacity: _showContent ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: Text(
          message,
          style: TextStyle(
            fontSize: screenSize.width * 0.04,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildViewMoreButtonPosition() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: _buildViewMoreButton(
          onPressed: () {
            setState(() {
              if (_isPendingSelected) {
                _pendingItemsToShow = _maxItemsToShow;
                _showPendingViewMoreButton = false;
              } else {
                _historyItemsToShow = _maxItemsToShow;
                _showHistoryViewMoreButton = false;
              }
            });
          },
          screenSize: MediaQuery.of(context).size,
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
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

    // Get colors - either from direct value or by calculating them
    Color typeColor;
    Color statusColor;
    IconData typeIcon;

    // If we have serialized color values (from cache), use them
    if (item['iconColorValue'] != null) {
      typeColor = Color(item['iconColorValue']);
    } else if (item['iconColor'] != null &&
        item['iconColor'] is String &&
        item['iconColor'].startsWith('#')) {
      // Parse from hex string if available
      final hexString = item['iconColor'].substring(1);
      typeColor = Color(int.parse(hexString, radix: 16));
    } else {
      // Fall back to calculating
      typeColor = _getTypeColor(type);
    }

    if (item['statusColorValue'] != null) {
      statusColor = Color(item['statusColorValue']);
    } else if (item['statusColor'] != null &&
        item['statusColor'] is String &&
        item['statusColor'].startsWith('#')) {
      // Parse from hex string if available
      final hexString = item['statusColor'].substring(1);
      statusColor = Color(int.parse(hexString, radix: 16));
    } else {
      // Fall back to calculating
      statusColor = _getStatusColor(item['status'] ?? 'waiting');
    }

    // Get icon - either from code point or by calculating
    typeIcon = _getIconForType(type);

    String formatDate(String dateStr) {
      try {
        final DateTime parsedDate = DateTime.parse(dateStr);
        return DateFormat('dd-MM-yyyy HH:mm').format(parsedDate);
      } catch (e) {
        return 'Invalid Date';
      }
    }

    String startDate =
        item['startDate'] != null ? formatDate(item['startDate']) : 'N/A';
    String endDate =
        item['endDate'] != null ? formatDate(item['endDate']) : 'N/A';

    return GestureDetector(
      onTap: () {
        String formattedStatus = item['status'] != null
            ? '${item['status'][0].toUpperCase()}${item['status'].substring(1).toLowerCase()}'
            : 'Waiting';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPage(
              types: type,
              id: item['id'] ?? '',
              status: formattedStatus,
            ),
          ),
        );
      },
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.05),
          side: BorderSide(color: typeColor, width: screenSize.width * 0.003),
        ),
        margin: EdgeInsets.symmetric(vertical: screenSize.height * 0.006),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: screenSize.height * 0.008,
            horizontal: screenSize.width * 0.025,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              SizedBox(
                width: screenSize.width * 0.1,
                child: type.toLowerCase() == 'minutes of meeting'
                    ? Image.asset(
                        'assets/room.png',
                        width: screenSize.width * 0.08,
                        height: screenSize.width * 0.08,
                        color: typeColor,
                      )
                    : Icon(
                        typeIcon,
                        color: typeColor,
                        size: screenSize.width * 0.08,
                      ),
              ),
              SizedBox(width: screenSize.width * 0.02),
              // Information Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayType(item['type'] ?? ''),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: screenSize.width * 0.035,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$startDate → $endDate',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        fontSize: screenSize.width * 0.026,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.002),
                    _buildDetailLabel(type, item, isDarkMode, screenSize),
                    SizedBox(height: screenSize.height * 0.002),
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: screenSize.width * 0.028,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.012,
                            vertical: screenSize.height * 0.002,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius:
                                BorderRadius.circular(screenSize.width * 0.015),
                          ),
                          child: Text(
                            item['status'].toString().toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenSize.width * 0.028,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenSize.width * 0.015),
              // Profile Image
              CircleAvatar(
                backgroundImage: NetworkImage(item['img_name']),
                radius: screenSize.width * 0.05,
                backgroundColor:
                    isDarkMode ? Colors.grey[700] : Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }

// Function to return proper detail label and text based on type
  Widget _buildDetailLabel(String type, Map<String, dynamic> item,
      bool isDarkMode, Size screenSize) {
    Color detailTextColor = Colors.grey;
    String detailLabel;
    String detailText;

    switch (type.toLowerCase()) {
      case 'meeting':
        detailLabel = 'Room:';
        detailText = item['room'] ?? 'N/A';
        detailTextColor = Colors.orange;
        break;
      case 'leave':
        detailLabel = 'Type:';
        detailText = item['leave_type'] ?? 'N/A';
        detailTextColor = Colors.orange;
        break;
      case 'car':
        detailLabel =
            'Place:'; //Should Tel. but no tel number in the api response
        detailText = item['place']?.toString() ?? 'No Place';
        detailTextColor = Colors.grey;
        break;
      case 'minutes of meeting':
        detailLabel = 'Room:';
        detailText = item['location'] ?? 'No location';
        detailTextColor = Colors.orange;
        break;
      default:
        detailLabel = 'Info:';
        detailText = 'N/A';
    }

    return Text(
      '$detailLabel $detailText',
      style: TextStyle(
        color: detailTextColor,
        fontSize: screenSize.width * 0.03,
      ),
    );
  }

  // Enhanced method to build the "View More" button
  Widget _buildViewMoreButton({
    required VoidCallback onPressed,
    required Size screenSize,
    required bool isDarkMode,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: screenSize.width * 0.4, // More compact width
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.012,
                  horizontal: screenSize.width * 0.03,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(screenSize.width * 0.05),
                  side: BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                elevation: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)?.viewMore ?? 'View More',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: screenSize.width * 0.02),
                  Icon(
                    Icons.arrow_downward,
                    size: screenSize.width * 0.04,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String pendingApiUrl = '$baseUrl/api/app/users/history/pending';
    final String historyApiUrl = '$baseUrl/api/app/users/history';
    final String leaveTypesUrl = '$baseUrl/api/leave-types';

    try {
      // Directly fetch from API, bypassing cache
      await _fetchDataFromApi(
          prefs, token, pendingApiUrl, historyApiUrl, leaveTypesUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data refreshed successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showContent = true;
        });
      }
    }
  }
}
