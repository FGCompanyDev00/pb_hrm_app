import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/home/office_events/add_member_office_event.dart';

class OfficeAddEventPage extends StatefulWidget {
  const OfficeAddEventPage({super.key});

  @override
  _OfficeAddEventPageState createState() => _OfficeAddEventPageState();
}

class _OfficeAddEventPageState extends State<OfficeAddEventPage> {
  String? _selectedBookingType;
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  List<Map<String, dynamic>> _selectedMembers = [];
  String _hoveredMemberName = '';

  @override
  void initState() {
    super.initState();
  }

  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<String> _fetchProfileImage(String employeeId) async {
    try {
      String token = await _fetchToken(); // Fetch the token from SharedPreferences

      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
        headers: {
          'Authorization': 'Bearer $token', // Pass the token in the header
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['results']['images']; // Return the 'images' field from the response
      } else {
        throw Exception('Failed to load profile image');
      }
    } catch (e) {
      throw Exception('Error fetching profile image: $e');
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startDateTime = DateTime(
            _startDateTime?.year ?? DateTime.now().year,
            _startDateTime?.month ?? DateTime.now().month,
            _startDateTime?.day ?? DateTime.now().day,
            picked.hour,
            picked.minute,
          );
        } else {
          _endDateTime = DateTime(
            _endDateTime?.year ?? DateTime.now().year,
            _endDateTime?.month ?? DateTime.now().month,
            _endDateTime?.day ?? DateTime.now().day,
            picked.hour,
            picked.minute,
          );
        }
      });
    }
  }

  void _showBookingTypeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('1. Add meeting'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '1. Add meeting';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('2. Meeting and Booking meeting room'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '2. Meeting and Booking meeting room';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('3. Booking car'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '3. Booking car';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: picked.hour, minute: picked.minute),
      );

      if (time != null) {
        setState(() {
          final selectedDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          if (isStartDate) {
            _startDateTime = selectedDateTime;
          } else {
            _endDateTime = selectedDateTime;
          }
        });
      }
    }
  }

  Future<void> _showAddPeoplePage() async {
    final selectedMembers = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddMemberPage(),
      ),
    );

    if (selectedMembers != null && selectedMembers.isNotEmpty) {
      setState(() {
        _selectedMembers = selectedMembers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 140,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/background.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30.0),
                    bottomRight: Radius.circular(30.0),
                  ),
                ),
              ),
              Positioned(
                top: 70.0,
                left: 16.0,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              const Positioned(
                top: 80.0,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Office',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 15.0),
                        ),
                        child: const Text(
                          '+ Add',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    const Text(
                      'Type of Booking*',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    GestureDetector(
                      onTap: () => _showBookingTypeModal(context),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: Colors.grey),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedBookingType ?? 'Select Booking Type'),
                            const Icon(Icons.menu),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Title*',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Description (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    // Start Date and Time Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () => _selectDate(context, true),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_startDateTime == null
                                          ? 'Start Date'
                                          : '${_startDateTime!.toLocal()}'.split(' ')[0]),
                                      const Icon(Icons.calendar_today),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () => _selectTime(context, true),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_startDateTime == null
                                          ? 'Start Time'
                                          : TimeOfDay.fromDateTime(_startDateTime!).format(context)),
                                      const Icon(Icons.access_time),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26.0),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () => _selectDate(context, false),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_endDateTime == null ? 'End Date' : '${_endDateTime!.toLocal()}'.split(' ')[0]),
                                      const Icon(Icons.calendar_today),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () => _selectTime(context, false),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_endDateTime == null
                                          ? 'End Time'
                                          : TimeOfDay.fromDateTime(_endDateTime!).format(context)),
                                      const Icon(Icons.access_time),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                    const SizedBox(height: 8.0),
                    if (_selectedBookingType == '1. Add meeting')
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: Colors.grey),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1. meeting onsite'),
                            Icon(Icons.menu),
                          ],
                        ),
                      )
                    else if (_selectedBookingType == '2. Meeting and Booking meeting room')
                      Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(color: Colors.grey),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('1. Local office'),
                                Icon(Icons.menu),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(color: Colors.grey),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('1. meeting at local office'),
                                Icon(Icons.menu),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (_selectedBookingType == '3. Booking car')
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(color: Colors.grey),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Car location selected'),
                              Icon(Icons.menu),
                            ],
                          ),
                        ),
                    const SizedBox(height: 16.0),
                    Center(
                      child: ElevatedButton(
                        onPressed: _showAddPeoplePage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                        ),
                        child: const Text(
                          '+ Add People',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _selectedMembers.map((member) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: FutureBuilder<String>(
                              future: _fetchProfileImage(member['employee_id']),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                } else if (snapshot.hasError) {
                                  return const Icon(Icons.error);
                                } else if (snapshot.hasData && snapshot.data != null) {
                                  return MouseRegion(
                                    onEnter: (_) {
                                      setState(() {
                                        _hoveredMemberName = member['name'];
                                      });
                                    },
                                    onExit: (_) {
                                      setState(() {
                                        _hoveredMemberName = '';
                                      });
                                    },
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(snapshot.data!),
                                      radius: 24.0,
                                    ),
                                  );
                                } else {
                                  return const Icon(Icons.error);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
