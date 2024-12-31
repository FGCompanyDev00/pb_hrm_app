// add_member_office_event.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/theme_notifier.dart';

class AddMemberPage extends StatefulWidget {
  const AddMemberPage({super.key});

  @override
  AddMemberPageState createState() => AddMemberPageState();
}

class AddMemberPageState extends State<AddMemberPage> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  final List<Map<String, dynamic>> _selectedMembers = [];

  List<Map<String, dynamic>> _groups = [];
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _fetchGroups();
  }

  /// Fetches the stored token from SharedPreferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  /// Fetches the list of members from the API, excluding the current logged-in user
  Future<void> _fetchMembers() async {
    try {
      String token = await _fetchToken();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? currentUserEmployeeId = prefs.getString('employee_id');

      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/project-member/get-all-employees'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['results'];
        setState(() {
          _members = data
              .where((item) => item['employee_id'] != currentUserEmployeeId)
              .map((item) => {
                    'id': item['id'],
                    'name': item['name'],
                    'surname': item['surname'],
                    'email': item['email'],
                    'employee_id': item['employee_id'],
                    // Combine name and surname to form employee_name
                    'employee_name': '${item['name']} ${item['surname']}'.trim(),
                  })
              .toList();
          _filteredMembers = _members;
        });
      } else {
        throw Exception('Failed to load members.');
      }
    } catch (e) {
      _showErrorMessage('Error fetching members: $e');
    }
  }

  /// Fetches the list of groups from the API
  Future<void> _fetchGroups() async {
    try {
      String token = await _fetchToken();
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/group/usergroups'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['results'];
        setState(() {
          _groups = data
              .map((item) => {
                    'id': item['id'],
                    'groupId': item['groupId'],
                    'group_name': item['group_name'],
                    'employees': item['employees'],
                  })
              .toList();
        });
      } else {
        throw Exception('Failed to load groups.');
      }
    } catch (e) {
      _showErrorMessage('Error fetching groups: $e');
    }
  }

  /// Fetches the profile image URL for the given employee ID
  Future<String?> _fetchProfileImage(String employeeId) async {
    try {
      String token = await _fetchToken();
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
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
        _selectedMembers.add({
          'employee_id': member['employee_id'],
          'employee_name': member['employee_name'],
          'email': member['email'],
        });
      } else {
        _selectedMembers.removeWhere((m) => m['employee_id'] == member['employee_id']);
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
      String fullName = '${member['name']} ${member['surname']}'.toLowerCase();
      return fullName.contains(query.toLowerCase());
    }).toList();
    setState(() {
      _filteredMembers = filteredList;
    });
  }

  /// Selects a group and adds its members
  void _selectGroup(String groupId) {
    final group = _groups.firstWhere((element) => element['groupId'] == groupId, orElse: () => {});
    if (group.isNotEmpty) {
      List<dynamic> employees = group['employees'];
      setState(() {
        for (var emp in employees) {
          if (!_selectedMembers.any((m) => m['employee_id'] == emp['employee_id'])) {
            _selectedMembers.add({
              'employee_id': emp['employee_id'],
              'employee_name': emp['employee_name'],
              'email': '', // Email not provided in group employees
            });
          }
        }
      });
    }
  }

  /// Shows an error message using a SnackBar
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Builds the group selection dropdown
  Widget _buildGroupDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Select Group',
        prefixIcon: const Icon(Icons.group),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
      value: _selectedGroupId,
      items: _groups
          .map((group) => DropdownMenuItem<String>(
                value: group['groupId'],
                child: Text(group['group_name']),
              ))
          .toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          _selectGroup(newValue);
        }
      },
    );
  }

  /// Builds the selected members avatar list
  Widget _buildSelectedMembersAvatars() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      height: 75,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(
                  _selectedMembers.length > 5 ? 6 : _selectedMembers.length,
                  (index) {
                    if (index == 5) {
                      return Positioned(
                        left: index * 30.0,
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey.shade800,
                          child: Text(
                            '+${_selectedMembers.length - 5}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                    final member = _selectedMembers[index];
                    return Positioned(
                      left: index * 30.0,
                      child: FutureBuilder<String?>(
                        future: _fetchProfileImage(member['employee_id']),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                            return CircleAvatar(
                              backgroundImage: snapshot.data != null ? NetworkImage(snapshot.data!) : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
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
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _onAddButtonPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE2AD30),
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            child: const Text(
              '+ Add',
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the member list item
  Widget _buildMemberListItem(Map<String, dynamic> member) {
    bool isSelected = _selectedMembers.any((m) => m['employee_id'] == member['employee_id']);
    return ListTile(
      leading: FutureBuilder<String?>(
        future: _fetchProfileImage(member['employee_id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
            return CircleAvatar(
              backgroundImage: NetworkImage(snapshot.data!),
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
      title: Text(member['employee_name']),
      subtitle: Text(member['email']),
      trailing: Checkbox(
        value: isSelected,
        activeColor: Colors.green,
        onChanged: (bool? selected) {
          _onMemberSelected(selected, member);
        },
      ),
      onTap: () {
        _onMemberSelected(!isSelected, member);
      },
    );
  }

  /// Builds the member list
  Widget _buildMemberList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _filteredMembers.length,
        itemBuilder: (context, index) {
          final member = _filteredMembers[index];
          return _buildMemberListItem(member);
        },
      ),
    );
  }

  /// Builds the search bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: TextField(
        onChanged: (value) {
          _filterMembers(value);
        },
        decoration: InputDecoration(
          labelText: 'Search',
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
      ),
    );
  }

  /// Builds the main content
  Widget _buildContent() {
    return Column(
      children: [
        if (_selectedMembers.isNotEmpty) _buildSelectedMembersAvatars(),
        const SizedBox(height: 10),
        _buildSearchBar(),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: _buildGroupDropdown(),
        ),
        const SizedBox(height: 10),
        _buildMemberList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive padding
    final double horizontalPadding = MediaQuery.of(context).size.width * 0.04;
    final double verticalPadding = MediaQuery.of(context).size.height * 0.01;

    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Members',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        child: _buildContent(),
      ),
    );
  }
}
