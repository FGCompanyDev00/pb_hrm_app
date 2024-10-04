// add_assignment_members.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SelectAssignmentMembersPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const SelectAssignmentMembersPage({
    Key? key,
    required this.projectId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  _SelectAssignmentMembersPageState createState() =>
      _SelectAssignmentMembersPageState();
}

class _SelectAssignmentMembersPageState
    extends State<SelectAssignmentMembersPage> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  final List<Map<String, dynamic>> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  /// Fetches the authentication token from SharedPreferences.
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    return token ?? '';
  }

  /// Fetches members associated with the given project ID.
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
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final List<dynamic> data = responseBody['Members'] ?? [];

        // Remove duplicate members based on employee_id
        final uniqueMembers = <String, Map<String, dynamic>>{};
        for (var item in data) {
          if (item == null) continue;
          String? employeeId = item['employee_id']?.toString();
          if (employeeId == null || employeeId.isEmpty) continue;

          if (!uniqueMembers.containsKey(employeeId)) {
            uniqueMembers[employeeId] = {
              'id': item['id']?.toString() ?? '',
              'employee_id': employeeId,
              'name': item['name']?.toString() ?? 'Unknown',
              'surname': item['surname']?.toString() ?? 'Unknown',
              'email': item['email']?.toString() ?? 'No Email',
              'images': item['images']?.toString() ?? '',
            };
          }
        }

        setState(() {
          _members = uniqueMembers.values.toList();
          _filteredMembers = _members;
        });

        // Fetch images for each member
        await _fetchMembersImages(token);
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

  /// Fetches profile images for each member using their employee_id.
  Future<void> _fetchMembersImages(String token) async {
    List<Future<void>> imageFetchFutures = _members.map((member) async {
      String employeeId = member['employee_id'];
      String? imageUrl = await _fetchMemberImage(employeeId, token);
      setState(() {
        member['image_url'] = imageUrl;
      });
    }).toList();

    await Future.wait(imageFetchFutures);
  }

  /// Fetches the profile image URL for a given employee_id.
  Future<String?> _fetchMemberImage(String employeeId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/profile/$employeeId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results']['images'] != null) {
          return data['results']['images'];
        }
      } else {
        print(
            'Failed to fetch image for $employeeId: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception while fetching image for $employeeId: $e');
    }
    return null;
  }

  /// Handles member selection and deselection.
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

  /// Navigates back with the selected members.
  void _onAddButtonPressed() {
    Navigator.pop(context, _selectedMembers);
  }

  /// Filters members based on the search query.
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

  /// Displays an error message using a SnackBar.
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Builds the UI for selected members' avatars.
  Widget _buildSelectedMembers() {
    if (_selectedMembers.isEmpty) return Container();
    int displayCount = _selectedMembers.length > 5 ? 5 : _selectedMembers.length;
    List<Widget> avatars = [];
    for (int i = 0; i < displayCount; i++) {
      avatars.add(
        Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: CircleAvatar(
            backgroundImage: _selectedMembers[i]['image_url'] != null &&
                _selectedMembers[i]['image_url'].isNotEmpty
                ? NetworkImage(_selectedMembers[i]['image_url'])
                : const AssetImage('assets/default_avatar.png') as ImageProvider,
            radius: 20,
            backgroundColor: Colors.grey[200],
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

  /// Builds the AppBar with consistent styling.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
        'Add Assignment Members',
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
    );
  }

  /// Constructs the full name, preventing duplication.
  String _constructFullName(Map<String, dynamic> member) {
    String name = member['name']?.toString() ?? '';
    String surname = member['surname']?.toString() ?? '';

    if (surname.isEmpty || surname.toLowerCase() == name.toLowerCase()) {
      return name;
    } else {
      return '$name $surname';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
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
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                        ),
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
                String fullName = _constructFullName(member);
                String email = member['email']?.isNotEmpty == true
                    ? member['email']
                    : 'No Email';
                String? imageUrl = member['image_url'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: imageUrl != null &&
                        imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : const AssetImage(
                        'assets/default_avatar.png')
                    as ImageProvider,
                    radius: 25,
                    backgroundColor: Colors.grey[200],
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
