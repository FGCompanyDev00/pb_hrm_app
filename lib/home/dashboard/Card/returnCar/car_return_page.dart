import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/home/dashboard/Card/returnCar/car_return_page_details.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReturnCarPage extends StatefulWidget {
  const ReturnCarPage({super.key});

  @override
  ReturnCarPageState createState() => ReturnCarPageState();
}

class ReturnCarPageState extends State<ReturnCarPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> events = [];
  List<dynamic> filteredEvents = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  String searchOption = 'requestor_name';
  bool isSearchFocused = false;
  List<String> recentSearches = [];
  bool showFilterOptions = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _searchBarAnimation;

  // Focus node for search field
  final FocusNode _searchFocusNode = FocusNode();

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    fetchEvents();
    searchController.addListener(_filterEvents);
    _loadRecentSearches();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _searchBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Add listener for focus changes
    _searchFocusNode.addListener(() {
      setState(() {
        isSearchFocused = _searchFocusNode.hasFocus;
        if (isSearchFocused) {
          _animationController.forward();
        } else {
          _animationController.reverse();
          showFilterOptions = false;
        }
      });
    });
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recent_car_searches') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList('recent_car_searches') ?? [];

    // Remove if already exists and add to the beginning
    searches.remove(query);
    searches.insert(0, query);

    // Keep only the last 5 searches
    if (searches.length > 5) {
      searches = searches.sublist(0, 5);
    }

    await prefs.setStringList('recent_car_searches', searches);
    setState(() {
      recentSearches = searches;
    });
  }

  Future<void> fetchEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      if (kDebugMode) {
        print('No token found');
      }
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/app/tasks/approvals/return'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        events = data['results'];
        filteredEvents = events;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      if (kDebugMode) {
        print('Failed to load events');
      }
    }
  }

  void _filterEvents() {
    String query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredEvents = events;
      });
    } else {
      setState(() {
        filteredEvents = events.where((event) {
          String valueToSearch;

          if (searchOption == 'requestor_name') {
            valueToSearch = (event['requestor_name'] ?? '').toLowerCase();
          } else {
            valueToSearch = (event['license_plate'] ?? '').toLowerCase();
          }

          return valueToSearch.contains(query);
        }).toList();
      });
    }
  }

  void _onSearchOptionChanged(String newValue) {
    setState(() {
      searchOption = newValue;
      _filterEvents();

      // Animate the change
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _onSearchSubmitted(String query) {
    _saveRecentSearch(query);
    _filterEvents();
    FocusScope.of(context).unfocus();
  }

  void _clearSearch() {
    setState(() {
      searchController.clear();
      filteredEvents = events;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'reject':
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final Color primaryColor =
        isDarkMode ? Colors.blueAccent.shade200 : Colors.blueAccent;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black // Background for dark mode
          : Colors.white, // Background for light mode

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          child: AppBar(
            flexibleSpace: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(isDarkMode
                      ? 'assets/darkbg.png'
                      : 'assets/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(top: 30.0),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white // White icon for dark mode
                      : Colors.black, // Black icon for light mode
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Text(
                'Car Return',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white // White text for dark mode
                      : Colors.black, // Black text for light mode
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Modern Search Box with Animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: isSearchFocused ? 16.0 : 12.0),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade900
                        : Colors.grey.shade100,
                    borderRadius:
                        BorderRadius.circular(isSearchFocused ? 20 : 30),
                    boxShadow: isSearchFocused
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 50,
                            height: 50,
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.search,
                              color: isSearchFocused
                                  ? primaryColor
                                  : (isDarkMode
                                      ? Colors.white70
                                      : Colors.black54),
                            )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .shimmer(
                                  duration: 2.seconds,
                                  color: isSearchFocused
                                      ? primaryColor
                                      : Colors.transparent,
                                ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              focusNode: _searchFocusNode,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: searchOption == 'requestor_name'
                                    ? 'Search by Requestor Name...'
                                    : 'Search by Car Plate...',
                                hintStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white60
                                      : Colors.black45,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              onSubmitted: _onSearchSubmitted,
                            ),
                          ),
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
                              onPressed: _clearSearch,
                            ).animate().fade().scale(),
                          IconButton(
                            icon: Icon(
                              showFilterOptions
                                  ? Icons.arrow_drop_up
                                  : Icons.filter_list,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                            onPressed: () {
                              setState(() {
                                showFilterOptions = !showFilterOptions;
                              });
                            },
                          ).animate().fade(),
                        ],
                      ),

                      // Filter Options
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: showFilterOptions
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 16, top: 8),
                                child: Wrap(
                                  spacing: 10,
                                  children: [
                                    FilterChip(
                                      label: const Text('Requestor Name'),
                                      selected:
                                          searchOption == 'requestor_name',
                                      checkmarkColor: Colors.white,
                                      selectedColor: primaryColor,
                                      backgroundColor: isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                      labelStyle: TextStyle(
                                        color: searchOption == 'requestor_name'
                                            ? Colors.white
                                            : (isDarkMode
                                                ? Colors.white70
                                                : Colors.black87),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          _onSearchOptionChanged(
                                              'requestor_name');
                                        }
                                      },
                                    ).animate().fade().scale(),
                                    FilterChip(
                                      label: const Text('Plate Number'),
                                      selected: searchOption == 'license_plate',
                                      checkmarkColor: Colors.white,
                                      selectedColor: primaryColor,
                                      backgroundColor: isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                      labelStyle: TextStyle(
                                        color: searchOption == 'license_plate'
                                            ? Colors.white
                                            : (isDarkMode
                                                ? Colors.white70
                                                : Colors.black87),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          _onSearchOptionChanged(
                                              'license_plate');
                                        }
                                      },
                                    ).animate().fade().scale(),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Recent Searches
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: isSearchFocused &&
                                searchController.text.isEmpty &&
                                recentSearches.isNotEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 16, top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Text(
                                        'Carian Terkini',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    ...recentSearches.map((search) => ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            Icons.history,
                                            size: 18,
                                            color: isDarkMode
                                                ? Colors.white60
                                                : Colors.black45,
                                          ),
                                          title: Text(
                                            search,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              searchController.text = search;
                                              _filterEvents();
                                              FocusScope.of(context).unfocus();
                                            });
                                          },
                                        ).animate().fadeIn(
                                            delay: 100.ms *
                                                recentSearches
                                                    .indexOf(search))),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                // Search Results Count
                AnimatedOpacity(
                  opacity: searchController.text.isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: searchController.text.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            children: [
                              Text(
                                'Ditemui ${filteredEvents.length} kereta',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              const Spacer(),
                              if (filteredEvents.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.sort, size: 16),
                                  label: const Text('Terkini'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    // Implement sorting functionality here
                                  },
                                ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Results
                if (filteredEvents.isEmpty && searchController.text.isNotEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 70,
                            color: isDarkMode
                                ? Colors.white30
                                : Colors.grey.shade300,
                          ).animate().fade().scale(),
                          const SizedBox(height: 16),
                          Text(
                            'Tiada kereta ditemui',
                            style: TextStyle(
                              fontSize: 18,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cuba carian yang lain',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white60
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReturnCarPageDetails(uid: event['uid']),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors
                                          .blueGrey // Dark mode border color
                                      : Colors
                                          .blueAccent, // Light mode border color
                                ),
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors
                                        .black45 // Dark mode background color
                                    : Colors
                                        .white, // Light mode background color
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    // Left section for car image and text
                                    Column(
                                      children: [
                                        Image.asset(
                                          'assets/car.png',
                                          width: 35,
                                          height: 35,
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Car',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueAccent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    // Main content section
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event['requestor_name'] ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors
                                                      .white // Dark mode text color
                                                  : Colors
                                                      .black, // Light mode text color
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Date: ${event['date_out']} To ${event['date_in']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors
                                                      .white70 // Lighter text in dark mode
                                                  : Colors.grey[
                                                      600], // Grey text in light mode
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Res ID: ${event['id']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors
                                                      .white70 // Lighter text in dark mode
                                                  : Colors.grey[
                                                      600], // Grey text in light mode
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tel: ${event['license_plate']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors
                                                      .white70 // Lighter text in dark mode
                                                  : Colors.grey[
                                                      600], // Grey text in light mode
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Text(
                                                'Status: ',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(
                                                      event['status'] ?? ''),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  event['status'] ?? '',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Right section for image
                                    Column(
                                      children: [
                                        ClipOval(
                                          child: Image.network(
                                            event['img_name'] ?? '',
                                            width: 45,
                                            height: 45,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'View Detail',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate(
                            effects: [
                              FadeEffect(
                                  duration: 400.ms,
                                  delay: 50.ms * index,
                                  curve: Curves.easeOutQuad),
                              SlideEffect(
                                  begin: const Offset(0.1, 0),
                                  end: const Offset(0, 0),
                                  duration: 400.ms,
                                  delay: 50.ms * index,
                                  curve: Curves.easeOutQuad)
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
