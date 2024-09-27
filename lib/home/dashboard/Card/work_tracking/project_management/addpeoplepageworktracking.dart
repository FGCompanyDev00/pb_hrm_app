import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/appbarclipper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AddPeoplePageWorkTracking extends StatefulWidget {
  final String asId;
  final String projectId;
  final Function(List<Map<String, dynamic>>) onSelectedPeople;

  const AddPeoplePageWorkTracking({
    super.key,
    required this.asId,
    required this.projectId,
    required this.onSelectedPeople,
  });

  @override
  _AddPeoplePageWorkTrackingState createState() => _AddPeoplePageWorkTrackingState();
}

class _AddPeoplePageWorkTrackingState extends State<AddPeoplePageWorkTracking> {
  List<Map<String, dynamic>> _members = [];
  final List<Map<String, dynamic>> _selectedPeople = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProjectMembers(); // Fetch available members for the project
  }

  Future<void> _fetchProjectMembers() async {
    setState(() {
      _isLoading = true; // Set loading state
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // Fetch the token from storage

      if (token == null) {
        throw Exception('No token found. Please log in again.');
      }

      // Fetch project members from the backend
      final url = Uri.parse(
          'https://demo-application-api.flexiflows.co/api/work-tracking/project-member/members?project_id=${widget.projectId}');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token', // Pass the token in the headers
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> membersList = data['results'];

        // Filter and prepare the list of members
        setState(() {
          _members = membersList.map<Map<String, dynamic>>((member) {
            return {
              'name': member['name'] ?? 'No Name',
              'surname': member['surname'] ?? '',
              'email': member['email'] ?? 'Unknown Email',
              'employee_id': member['employee_id'],
              'isSelected': false, // Track selection
            };
          }).toList();
        });
      } else {
        throw Exception('Failed to load project members');
      }
    } catch (e) {
      print('Error fetching project members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching project members: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Loading is done
      });
    }
  }

  Future<void> _fetchProfileImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // Fetch the token from storage

      if (token == null) {
        throw Exception('No token found. Please log in again.');
      }

      // Fetch profile images for each member
      for (var member in _members) {
        final employeeId = member['employee_id'];
        final response = await http.get(
          Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
          headers: {
            'Authorization': 'Bearer $token', // Include the token in the request headers
          },
        );

        if (response.statusCode == 200) {
          final profileData = jsonDecode(response.body);
          setState(() {
            member['images'] = profileData['images'] ?? ''; // Update the image URL
          });
        } else {
          print('Failed to load profile image for $employeeId: ${response.body}');
        }
      }
    } catch (e) {
      print('Error fetching profile images: $e');
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      _members[index]['isSelected'] = !_members[index]['isSelected'];
    });
  }

  void _onAddMembersPressed() {
    final selectedMembers = _members.where((member) => member['isSelected']).toList();
    if (selectedMembers.isNotEmpty) {
      widget.onSelectedPeople(selectedMembers); // Return selected members
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
    }
  }

Future<void> _confirmSelection() async {
  final selectedMembers = _members.where((member) => member['isSelected']).toList();

  // Ensure that only valid employee IDs are included in the request
  final List<Map<String, dynamic>> memberDetails = selectedMembers
      .map<Map<String, dynamic>>((member) => {
        if (member['employee_id'] != null && member['employee_id'].isNotEmpty)
          'employee_id': member['employee_id']
      })
      .where((member) => member.containsKey('employee_id')) // Filter out any empty entries
      .toList();

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // Fetch token for authenticated requests

    if (token == null) {
      throw Exception('No token found');
    }

    final url = Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/assignment-members/update/${widget.projectId}'); // Updated URL for member update
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'assignment_id': widget.asId, // Pass the assignment ID
        'memberDetails': memberDetails, // Pass the selected members
      }),
    );

    // Print status code and body to help debug
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Members updated successfully!');
      Navigator.pop(context, true); // Close modal and return success
    } else {
      final responseBody = jsonDecode(response.body);
      throw Exception('Failed to update members: ${responseBody['error'] ?? response.body}');
    }
  } catch (e) {
    print('Error updating members: $e');
   
  }
}

  void _showMemberDetails(String employeeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Member Details'),
        content: Text('Employee Name: $employeeName'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter members based on the search query
    final filteredMembers = _members.where((member) {
      final memberName = member['name']?.toLowerCase() ?? '';
      return memberName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add People',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: ClipPath(
          clipper: CustomAppBarClipper(),
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator when loading
          : Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ),
          // Member list
          Expanded(
            child: ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                final imageUrl = member['image'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => _showMemberDetails(member['name']), // Show member details on tap
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(imageUrl),
                        onBackgroundImageError: (exception, stackTrace) {
                          if (kDebugMode) {
                            print('Error loading image for employee ${member['employee_id']}: $exception');
                          }
                        },
                      ),
                    ),
                    title: Text(member['name'] ?? 'No Name'),
                    subtitle: Text('${member['surname']} - ${member['email']}'),
                    trailing: Checkbox(
                      value: member['isSelected'], // Checkbox for selecting the member
                      onChanged: (bool? value) {
                        _toggleSelection(index); // Toggle selection on checkbox change
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          // Button to confirm selected members
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                _onAddMembersPressed(); // Confirm selected members
                _confirmSelection(); // Confirm and save the selected members
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Members'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}





