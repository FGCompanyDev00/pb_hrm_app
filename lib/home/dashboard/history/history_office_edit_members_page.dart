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

  @override
  void initState() {
    super.initState();
    _selectedMembers = List<Map<String, dynamic>>.from(widget.initialSelectedMembers);
    _fetchAllMembers();
  }

  /// Fetches the stored token from SharedPreferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  /// Fetches all members from the API
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
              'img_name': item['img_name'],
            }));
            _filteredMembers = List<Map<String, dynamic>>.from(_allMembers);
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

  /// Filters the members based on the search query
  void _filterMembers(String query) {
    List<Map<String, dynamic>> filteredList = _allMembers
        .where((member) =>
        member['employee_name']
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    setState(() {
      _filteredMembers = filteredList;
    });
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

  /// Builds the members list
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
              // Handle image load error by setting default avatar
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Members'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 90,
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
        iconTheme: const IconThemeData(color: Colors.black), // Back button color
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          style:
          const TextStyle(color: Colors.red, fontSize: 16.0),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Box
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
            // Members List
            Expanded(
              child: SingleChildScrollView(
                child: _buildMembersList(),
              ),
            ),
            // Add Button
            ElevatedButton(
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
          ],
        ),
      ),
    );
  }
}
