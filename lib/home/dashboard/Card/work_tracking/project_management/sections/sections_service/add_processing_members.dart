// add_processing_members.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SelectProcessingMembersPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const SelectProcessingMembersPage({
    Key? key,
    required this.projectId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  _SelectProcessingMembersPageState createState() =>
      _SelectProcessingMembersPageState();
}

class _SelectProcessingMembersPageState
    extends State<SelectProcessingMembersPage> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  final List<Map<String, dynamic>> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  /// Fetches the stored token from SharedPreferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    print('Using Token: $token'); // Debugging line
    return token ?? '';
  }

  /// Fetches the list of members from the API
  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      String token = await _fetchToken();
      if (token.isEmpty) {
        throw Exception('Token not found. Please log in again.');
      }

      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/work-tracking/proj/find-Member-By-ProjectId/${widget.projectId}'),
        headers: {
          'Authorization': 'Bearer $token',
          // Add other headers if required by the API
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        print('API Response: ${response.body}'); // Debugging line

        // **Update the key from 'results' to 'Members'**
        final List<dynamic> data = responseBody['Members'] ?? [];

        if (data.isEmpty) {
          print('No members found in the API response.');
        }

        // Remove duplicates based on 'employee_id'
        final uniqueMembers = <String, Map<String, dynamic>>{};
        for (var item in data) {
          if (item == null) continue; // Skip null items
          String? employeeId = item['employee_id']?.toString();
          if (employeeId == null || employeeId.isEmpty) continue; // Skip if employee_id is null

          if (!uniqueMembers.containsKey(employeeId)) {
            uniqueMembers[employeeId] = {
              'id': item['id']?.toString() ?? '',
              'employee_id': employeeId,
              // Initialize other fields; we'll populate them later
              'name': '',
              'surname': '',
              'email': '',
              'images': '',
            };
          }
        }

        // Fetch member details in parallel
        List<String> employeeIds = uniqueMembers.keys.toList();
        await _fetchMemberDetailsBatch(employeeIds, uniqueMembers, token);

        setState(() {
          _members = uniqueMembers.values.toList();
          _filteredMembers = _members;
        });
      } else {
        throw Exception('Failed to load members: ${response.body}');
      }
    } catch (e) {
      _showErrorMessage('Error fetching members: $e');
    }
    setState(() {
      _isLoading = false;
    });
  }

  /// Fetches member details in batch
  Future<void> _fetchMemberDetailsBatch(List<String> employeeIds,
      Map<String, Map<String, dynamic>> uniqueMembers, String token) async {
    if (employeeIds.isEmpty) return;

    try {
      // Example batch API call; adjust based on your backend's capabilities
      // If your backend doesn't support batch, you need to fetch individually
      // For demonstration, we'll fetch individually using Future.wait

      List<Future<void>> fetchDetailsFutures = [];
      for (String employeeId in employeeIds) {
        fetchDetailsFutures.add(
            _fetchMemberDetails(employeeId, uniqueMembers, token));
      }

      await Future.wait(fetchDetailsFutures);
    } catch (e) {
      print('Error fetching member details batch: $e');
      // Optionally, set default values or handle errors as needed
    }
  }

  /// Fetches the profile image URL and other details for a given employee ID
  Future<void> _fetchMemberDetails(String employeeId,
      Map<String, Map<String, dynamic>> uniqueMembers, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/profile/$employeeId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        print('Profile API Response for employee_id $employeeId: ${response.body}'); // Debugging line

        // Adjust the key based on your actual API response
        final Map<String, dynamic>? profileData = responseBody['profile'];

        if (profileData != null) {
          uniqueMembers[employeeId]!['name'] = profileData['name']?.toString() ?? '';
          uniqueMembers[employeeId]!['surname'] =
              profileData['surname']?.toString() ?? '';
          uniqueMembers[employeeId]!['email'] = profileData['email']?.toString() ?? '';
          uniqueMembers[employeeId]!['images'] = profileData['images']?.toString() ?? '';
        } else {
          // Handle cases where 'profile' key is missing
          uniqueMembers[employeeId]!['name'] = 'Unknown';
          uniqueMembers[employeeId]!['surname'] = 'Unknown';
          uniqueMembers[employeeId]!['email'] = 'Unknown';
          uniqueMembers[employeeId]!['images'] = '';
          print('Profile data is null for employee_id $employeeId');
        }
      } else {
        // Handle non-200 responses
        uniqueMembers[employeeId]!['name'] = 'Unknown';
        uniqueMembers[employeeId]!['surname'] = 'Unknown';
        uniqueMembers[employeeId]!['email'] = 'Unknown';
        uniqueMembers[employeeId]!['images'] = '';
        print('Failed to fetch profile for employee_id $employeeId: ${response.body}');
      }
    } catch (e) {
      // Handle errors
      uniqueMembers[employeeId]!['name'] = 'Error';
      uniqueMembers[employeeId]!['surname'] = 'Error';
      uniqueMembers[employeeId]!['email'] = 'Error';
      uniqueMembers[employeeId]!['images'] = '';
      print('Error fetching details for employee_id $employeeId: $e');
    }
  }

  /// Handles member selection
  void _onMemberSelected(bool? selected, Map<String, dynamic> member) {
    setState(() {
      if (selected == true) {
        if (!_selectedMembers
            .any((m) => m['employee_id'] == member['employee_id'])) {
          _selectedMembers.add(member);
        }
      } else {
        _selectedMembers
            .removeWhere((m) => m['employee_id'] == member['employee_id']);
      }
    });
  }

  /// Returns to the previous screen with the selected members
  void _onAddButtonPressed() {
    Navigator.pop(context, _selectedMembers);
  }

  /// Filters the members based on the search query
  void _filterMembers(String query) {
    List<Map<String, dynamic>> filteredList = _members.where((member) {
      String name = member['name']?.toLowerCase() ?? '';
      String surname = member['surname']?.toLowerCase() ?? '';
      return name.contains(query.trim().toLowerCase()) ||
          surname.contains(query.trim().toLowerCase());
    }).toList();
    setState(() {
      _filteredMembers = filteredList;
    });
  }

  /// Shows an error message using a SnackBar
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Builds the selected members' avatars
  Widget _buildSelectedMembers() {
    if (_selectedMembers.isEmpty) return Container();
    int displayCount = _selectedMembers.length > 5 ? 5 : _selectedMembers.length;
    List<Widget> avatars = [];
    for (int i = 0; i < displayCount; i++) {
      avatars.add(
        Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: CircleAvatar(
            backgroundImage: _selectedMembers[i]['images'] != null &&
                _selectedMembers[i]['images'] != ''
                ? NetworkImage(_selectedMembers[i]['images'])
                : const AssetImage('assets/default_avatar.png') as ImageProvider,
            radius: 20,
          ),
        ),
      );
    }
    if (_selectedMembers.length > 5) {
      avatars.add(
        CircleAvatar(
          backgroundColor: Colors.grey[300],
          radius: 20,
          child: Text(
            '+${_selectedMembers.length - 5}',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      );
    }
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: avatars,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Add Processing Members',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_selectedMembers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              height: 80,
              child: Row(
                children: [
                  _buildSelectedMembers(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: ElevatedButton(
                      onPressed: _onAddButtonPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40.0, vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      child: const Text(
                        '+ Add',
                        style:
                        TextStyle(color: Colors.black, fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                _filterMembers(value);
              },
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredMembers.isEmpty
                ? const Center(child: Text('No members found.'))
                : ListView.builder(
              itemCount: _filteredMembers.length,
              itemBuilder: (context, index) {
                final member = _filteredMembers[index];
                String fullName =
                    '${member['name'].isNotEmpty ? member['name'] : 'Unknown'} '
                    '${member['surname'].isNotEmpty ? member['surname'] : 'Unknown'}';
                String email =
                member['email'].isNotEmpty ? member['email'] : 'No Email';
                String imageUrl =
                member['images'].isNotEmpty ? member['images'] : '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : const AssetImage('assets/default_avatar.png')
                    as ImageProvider,
                    radius: 25,
                  ),
                  title: Text(
                    fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: member['name'] == 'Error'
                          ? Colors.red
                          : Colors.black,
                    ),
                  ),
                  subtitle: Text(email),
                  trailing: Checkbox(
                    value: _selectedMembers.any((m) =>
                    m['employee_id'] == member['employee_id']),
                    activeColor: Colors.green,
                    onChanged: (bool? selected) {
                      _onMemberSelected(selected, member);
                    },
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
