import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class  SelectProcessingMembersPage extends StatefulWidget {
  final String projectId;
  const SelectProcessingMembersPage({super.key, required this.projectId});

  @override
  _SelectProcessingMembersPage createState() => _SelectProcessingMembersPage();
}

class _SelectProcessingMembersPage extends State<SelectProcessingMembersPage> {

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  final List<Map<String, dynamic>> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  /// Fetches the stored token from SharedPreferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  /// Fetches the list of members from the API
  Future<void> _fetchMembers() async {
    try {
      String token = await _fetchToken();
      final response = await http.get(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/work-tracking/project-member/get-all-employees'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['results'];
        setState(() {
          _members = data.map((item) => {
            'id': item['id'],
            'name': item['name'],
            'surname': item['surname'],
            'email': item['email'],
            'employee_id': item['employee_id'],
          }).toList();
          _filteredMembers = _members;
        });
      } else {
        throw Exception('Failed to load members');
      }
    } catch (e) {
      _showErrorMessage('Error fetching members: $e');
    }
  }

  /// Fetches the profile image URL for the given employee ID
  Future<String?> _fetchProfileImage(String employeeId) async {
    try {
      String token = await _fetchToken();
      final response = await http.get(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['results'];
        return data['images'];
      }
    } catch (e) {
      // Handle errors if necessary
    }
    return null;
  }

  /// Handles member selection
  void _onMemberSelected(bool? selected, Map<String, dynamic> member) {
    setState(() {
      if (selected == true) {
        _selectedMembers.add(member);
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
    List<Map<String, dynamic>> filteredList = _members
        .where((member) =>
    member['name'].toLowerCase().contains(query.toLowerCase()) ||
        member['surname'].toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      _filteredMembers = filteredList;
    });
  }

  /// Shows an error message using a SnackBar
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Builds the main UI of the page
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
          'Add Members',
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
      body: Column(
        children: [
          if (_selectedMembers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              height: 80,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedMembers.length > 3
                          ? 3
                          : _selectedMembers.length,
                      itemBuilder: (context, index) {
                        final member = _selectedMembers[index];
                        return FutureBuilder<String?>(
                          future: _fetchProfileImage(member['employee_id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done &&
                                snapshot.hasData) {
                              return Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                                child: CircleAvatar(
                                  backgroundImage: snapshot.data != null
                                      ? NetworkImage(snapshot.data!)
                                      : const AssetImage(
                                      'assets/default_avatar.png')
                                  as ImageProvider,
                                  radius: 25,
                                ),
                              );
                            } else {
                              return const CircleAvatar(
                                backgroundColor: Colors.grey,
                                radius: 25,
                                child: Icon(Icons.person, color: Colors.white),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  if (_selectedMembers.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[300],
                        child: Text('+${_selectedMembers.length - 3}',
                            style: const TextStyle(color: Colors.black)),
                      ),
                    ),
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
                        style: TextStyle(color: Colors.black, fontSize: 18),
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
            child: ListView.builder(
              itemCount: _filteredMembers.length,
              itemBuilder: (context, index) {
                final member = _filteredMembers[index];
                return ListTile(
                  leading: FutureBuilder<String?>(
                    future: _fetchProfileImage(member['employee_id']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        return CircleAvatar(
                          backgroundImage: snapshot.data != null
                              ? NetworkImage(snapshot.data!)
                              : const AssetImage('assets/default_avatar.png')
                          as ImageProvider,
                          radius: 25,
                        );
                      } else {
                        return const CircleAvatar(
                          backgroundColor: Colors.grey,
                          radius: 25,
                          child: Icon(Icons.person, color: Colors.white),
                        );
                      }
                    },
                  ),
                  title: Text('${member['name']} ${member['surname']}'),
                  subtitle: Text(member['email']),
                  trailing: Checkbox(
                    value: _selectedMembers.any(
                            (m) => m['employee_id'] == member['employee_id']),
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
