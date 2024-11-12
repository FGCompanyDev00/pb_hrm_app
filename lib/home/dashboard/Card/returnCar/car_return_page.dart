import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pb_hrsystem/home/dashboard/Card/returnCar/car_return_page_details.dart';

class ReturnCarPage extends StatefulWidget {
  const ReturnCarPage({super.key});

  @override
  _ReturnCarPageState createState() => _ReturnCarPageState();
}

class _ReturnCarPageState extends State<ReturnCarPage> {
  List<dynamic> events = [];
  List<dynamic> filteredEvents = []; // List to hold filtered events
  bool isLoading = true;
  TextEditingController searchController = TextEditingController(); // Controller for search input
  String searchOption = 'requestor_name'; // Default search option

  @override
  void initState() {
    super.initState();
    fetchEvents();
    searchController.addListener(_filterEvents); // Add listener to search field
  }

  // Fetch events from API
  Future<void> fetchEvents() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    // Get the Bearer Token from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');  // Assuming the token is saved as 'token'

    if (token == null) {
      // Handle case where the token is not available
      setState(() {
        isLoading = false;
      });
      if (kDebugMode) {
        print('No token found');
      }
      return;
    }

    // Add the token to the request headers
    final response = await http.get(
      Uri.parse('$baseUrl/api/app/tasks/approvals/return'),
      headers: {
        'Authorization': 'Bearer $token',  // Add the token here
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        events = data['results'];
        filteredEvents = events; // Initially, show all events
        isLoading = false;
      });
    } else {
      // Handle error response
      setState(() {
        isLoading = false;
      });
      if (kDebugMode) {
        print('Failed to load events: ${response.statusCode}');
      }
    }
  }

  // Function to filter events based on search input
  void _filterEvents() {
    String query = searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredEvents = events; // If search is empty, show all events
      });
    } else {
      setState(() {
        filteredEvents = events.where((event) {
          String valueToSearch;

          // Choose search criterion based on selected search option
          if (searchOption == 'requestor_name') {
            valueToSearch = (event['requestor_name'] ?? '').toLowerCase();
          } else {
            valueToSearch = (event['license_plate'] ?? '').toLowerCase();
          }

          return valueToSearch.contains(query); // Filter based on selected option
        }).toList();
      });
    }
  }

  // Function to handle the dropdown selection for search criteria
  void _onSearchOptionChanged(String? newValue) {
    setState(() {
      searchOption = newValue!;
      // Reset the filtered events to the original list when the search option changes
      filteredEvents = events;
    });
  }

  // Helper function to get status color based on the status value
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
        return Colors.grey; // Default color if no status matches
    }
  }

  @override
  void dispose() {
    searchController.dispose(); // Dispose controller when not in use
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          child: AppBar(
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(top: 30.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: const Padding(
              padding: EdgeInsets.only(top: 40.0),
              child: Text(
                'Return',
                style: TextStyle(
                  color: Colors.black,
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
          // Search bar and dropdown for selecting search criteria
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: DropdownButton<String>(
                        value: searchOption,
                        icon: const Icon(Icons.arrow_drop_down),
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
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Display a message if no results are found
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
                          builder: (context) => const ReturnCarPageDetails(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueAccent),
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  Image.asset(
                                    'assets/car.png',
                                    width: 40,
                                    height: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Car',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event['requestor_name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${event['date_out']} To ${event['date_in']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tel: ${event['license_plate']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text(
                                          'Status: ',
                                          style: TextStyle(
                                            fontSize: 14,
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
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                children: [
                                  ClipOval(
                                    child: Image.network(
                                      event['img_name'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'View Detail',
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
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
