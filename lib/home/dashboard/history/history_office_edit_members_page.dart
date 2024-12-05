// history_office_edit_members_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfficeEditMembersPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialSelectedMembers;
  final String meetingId;

  const OfficeEditMembersPage({
    super.key,
    required this.initialSelectedMembers,
    required this.meetingId,
  });

  @override
  _OfficeEditMembersPageState createState() => _OfficeEditMembersPageState();
}

class _OfficeEditMembersPageState extends State<OfficeEditMembersPage> {
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  List<Map<String, dynamic>> _selectedMembers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId; // Added variable to store current user ID

  @override
  void initState() {
    super.initState();
    _selectedMembers = List<Map<String, dynamic>>.from(widget.initialSelectedMembers);
    _fetchCurrentUserId().then((_) {
      _fetchAllMembers();
    });
  }

  /// Fetches the current user's employee ID from shared preferences
  Future<void> _fetchCurrentUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('employee_id') ?? '';
    });
  }

  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _fetchAllMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String token = await _fetchToken();
      String url =
          'https://demo-application-api.flexiflows.co/api/work-tracking/project-member/get-all-employees';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('Fetching Members from URL: $url');
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body)['results'];
        if (data is List) {
          setState(() {
            _allMembers = List<Map<String, dynamic>>.from(data.map((item) => {
              'employee_id': item['employee_id'],
              'employee_name': '${item['name']} ${item['surname']}',
              'img_name': null, // Placeholder, will fetch actual image later
            }));

            // Exclude the current user from the list
            _allMembers.removeWhere(
                    (member) => member['employee_id'] == _currentUserId);

            _filteredMembers = List<Map<String, dynamic>>.from(_allMembers);
            _fetchImages();
          });
        } else {
          throw Exception('Invalid members data');
        }
      } else {
        throw Exception('Failed to fetch members: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching members: $e';
      });
      if (kDebugMode) {
        print('Error fetching members: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchImages() async {
    for (var member in _allMembers) {
      try {
        String token = await _fetchToken();
        String url =
            'https://demo-application-api.flexiflows.co/api/profile/${member['employee_id']}';

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final profileData = jsonDecode(response.body)['results'];
          setState(() {
            member['img_name'] =
                profileData['images'] ?? 'https://www.w3schools.com/howto/img_avatar.png';
          });
        } else {
          if (kDebugMode) {
            print('Failed to fetch image for ${member['employee_id']}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching image for ${member['employee_id']}: $e');
        }
      }
    }
  }

  void _filterMembers(String query) {
    List<Map<String, dynamic>> filteredList = _allMembers
        .where((member) =>
        member['employee_name'].toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      _filteredMembers = filteredList;
    });
  }

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

  void _onAddButtonPressed() {
    Navigator.pop(context, _selectedMembers);
  }

  Widget _buildMembersList() {
    return _filteredMembers.isNotEmpty
        ? ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredMembers.length,
      itemBuilder: (context, index) {
        final member = _filteredMembers[index];
        bool isSelected = _selectedMembers
            .any((m) => m['employee_id'] == member['employee_id']);
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
                member['img_name'] ??
                    'https://www.w3schools.com/howto/img_avatar.png'),
            onBackgroundImageError: (_, __) {
              setState(() {
                member['img_name'] =
                'https://www.w3schools.com/howto/img_avatar.png';
              });
            },
          ),
          title: Text(member['employee_name'] ?? 'No Name'),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (bool? selected) {
              _onMemberSelected(selected, member);
            },
          ),
          onTap: () {
            _onMemberSelected(!isSelected, member);
          },
        );
      },
    )
        : const Text(
      'No members found.',
      style: TextStyle(color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Members',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black, // Title color based on theme
          ),
        ),
        backgroundColor: Colors.transparent, // Transparent background for the AppBar
        elevation: 0,
        toolbarHeight: 90,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black, // Icon color changes based on theme
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 16.0),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _onAddButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDBB342),
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
            const SizedBox(height: 16.0),
            TextField(
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
            const SizedBox(height: 16.0),
            Expanded(
              child: SingleChildScrollView(
                child: _buildMembersList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
