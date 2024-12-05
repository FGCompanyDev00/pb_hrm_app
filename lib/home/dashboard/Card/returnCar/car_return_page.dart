import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/home/dashboard/Card/returnCar/car_return_page_details.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


class ReturnCarPage extends StatefulWidget {
  const ReturnCarPage({super.key});

  @override
  _ReturnCarPageState createState() => _ReturnCarPageState();
}

class _ReturnCarPageState extends State<ReturnCarPage> {
  List<dynamic> events = [];
  List<dynamic> filteredEvents = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  String searchOption = 'requestor_name';

  @override
  void initState() {
    super.initState();
    fetchEvents();
    searchController.addListener(_filterEvents);
  }

  Future<void> fetchEvents() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

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
        print('Failed to load events: ${response.statusCode}');
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

  void _onSearchOptionChanged(String? newValue) {
    setState(() {
      searchOption = newValue!;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
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
                  image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
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
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white, // Background color based on theme
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white // Text color in dark mode
                          : Colors.black, // Text color in light mode
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70 // Lighter hint color in dark mode
                            : Colors.black54, // Lighter hint color in light mode
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70 // Icon color in dark mode
                            : Colors.black54, // Icon color in light mode
                      ),
                      suffixIcon: DropdownButton<String>(
                        value: searchOption,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white // Dropdown icon in dark mode
                              : Colors.black, // Dropdown icon in light mode
                        ),
                        onChanged: _onSearchOptionChanged,
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'requestor_name',
                            child: Text('Requestor Name'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'license_plate',
                            child: Text('License Plate'),
                          ),
                        ],
                        dropdownColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black // Dropdown menu background in dark mode
                            : Colors.white, // Dropdown menu background in light mode
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(60),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filteredEvents.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No results found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
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
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.blueGrey // Dark mode border color
                                : Colors.blueAccent, // Light mode border color
                          ),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black45 // Dark mode background color
                              : Colors.white, // Light mode background color
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
                                    width: 40,
                                    height: 40,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event['requestor_name'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white // Dark mode text color
                                            : Colors.black, // Light mode text color
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${event['date_out']} To ${event['date_in']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white70 // Lighter text in dark mode
                                            : Colors.grey[600], // Grey text in light mode
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tel: ${event['license_plate']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white70 // Lighter text in dark mode
                                            : Colors.grey[600], // Grey text in light mode
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Purpose: ${event['purpose']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white70 // Lighter text in dark mode
                                            : Colors.grey[600], // Grey text in light mode
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(event['status'] ?? ''),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            event['status'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
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
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
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
