// add_processing_members.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SelectProcessingMembersPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;
  final List<Map<String, dynamic>> alreadySelectedMembers;

  const SelectProcessingMembersPage({
    Key? key,
    required this.projectId,
    required this.baseUrl,
    this.alreadySelectedMembers = const [],
  }) : super(key: key);

  @override
  _SelectProcessingMembersPageState createState() =>
      _SelectProcessingMembersPageState();
}

class _SelectProcessingMembersPageState
    extends State<SelectProcessingMembersPage> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  List<Map<String, dynamic>> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMembers = List.from(widget.alreadySelectedMembers);
    _fetchMembers();
  }

  // Fetch the token from SharedPreferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    print('[_SelectProcessingMembersPageState] Retrieved token: $token');
    return token ?? '';
  }

  // Fetch members based on projectId
  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
    });
    print(
        '[_SelectProcessingMembersPageState] Fetching members for projectId: ${widget.projectId}, baseUrl: ${widget.baseUrl}');

    try {
      String token = await _fetchToken();
      if (token.isEmpty) {
        throw Exception('Token not found. Please log in again.');
      }

      String apiUrl =
          '${widget.baseUrl}/api/work-tracking/proj/find-Member-By-ProjectId/${widget.projectId}';
      print('[_SelectProcessingMembersPageState] API URL: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print(
          '[_SelectProcessingMembersPageState] API Response Status Code: ${response.statusCode}');
      print('[_SelectProcessingMembersPageState] API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        print('[_SelectProcessingMembersPageState] Parsed response body.');

        final List<dynamic> data = responseBody['Members'] ?? [];
        print(
            '[_SelectProcessingMembersPageState] Number of members fetched: ${data.length}');

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
              'surname': item['surname']?.toString() ?? '',
              'email': item['email']?.toString() ?? 'No Email',
              'image_url': '', // Placeholder for image URL
            };
          }
        }

        setState(() {
          _members = uniqueMembers.values.toList();
          _filteredMembers = _members;
        });

        print(
            '[_SelectProcessingMembersPageState] Unique members count after filtering: ${_members.length}');

        // Fetch images for each member
        await _fetchMembersImages(token);
      } else {
        throw Exception(
            'Failed to load members: ${response.statusCode}, ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorMessage('Error fetching members: $e');
    }
    setState(() {
      _isLoading = false;
    });
  }

  // Fetch member images
  Future<void> _fetchMembersImages(String token) async {
    List<Future<void>> imageFetchFutures = _members.map((member) async {
      String employeeId = member['employee_id'];
      String? imageUrl = await _fetchMemberImage(employeeId, token);
      setState(() {
        member['image_url'] = imageUrl ?? '';
      });
      print(
          '[_SelectProcessingMembersPageState] Member: $employeeId, Image URL: ${member['image_url']}');
    }).toList();

    await Future.wait(imageFetchFutures);
    print('[_SelectProcessingMembersPageState] Completed fetching member images.');
  }

  // Fetch individual member image
  Future<String?> _fetchMemberImage(String employeeId, String token) async {
    try {
      String apiUrl = '${widget.baseUrl}/api/profile/$employeeId';
      print(
          '[_SelectProcessingMembersPageState] Fetching image for employeeId: $employeeId, API URL: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print(
          '[_SelectProcessingMembersPageState] Image API Response Status Code: ${response.statusCode}');
      print('[_SelectProcessingMembersPageState] Image API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results']['images'] != null) {
          print('[_SelectProcessingMembersPageState] Found image URL for $employeeId');
          return data['results']['images'];
        } else {
          print('[_SelectProcessingMembersPageState] No image found for $employeeId');
        }
      } else {
        print(
            '[_SelectProcessingMembersPageState] Failed to fetch image for $employeeId: ${response.statusCode}');
      }
    } catch (e) {
      print('[_SelectProcessingMembersPageState] Exception while fetching image for $employeeId: $e');
    }
    return null;
  }

  // Handle member selection
  void _onMemberSelected(bool? selected, Map<String, dynamic> member) {
    setState(() {
      if (selected == true) {
        if (!_selectedMembers
            .any((m) => m['employee_id'] == member['employee_id'])) {
          _selectedMembers.add(member);
          print(
              '[_SelectProcessingMembersPageState] Selected member: ${member['employee_id']}');
        }
      } else {
        _selectedMembers
            .removeWhere((m) => m['employee_id'] == member['employee_id']);
        print(
            '[_SelectProcessingMembersPageState] Deselected member: ${member['employee_id']}');
      }
    });
  }

  // Handle Add button press
  void _onAddButtonPressed() {
    print(
        '[_SelectProcessingMembersPageState] Adding selected members: ${_selectedMembers.map((m) => m['employee_id']).toList()}');
    Navigator.pop(context, _selectedMembers);
  }

  // Filter members based on search query
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
    print(
        '[_SelectProcessingMembersPageState] Filtered members count: ${_filteredMembers.length}');
  }

  // Display error messages
  void _showErrorMessage(String message) {
    print('[_SelectProcessingMembersPageState] $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Display selected members as avatars
  Widget _buildSelectedMembers() {
    if (_selectedMembers.isEmpty) return const Text('No members selected.');
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

  // Custom AppBar with background image and styling
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
    );
  }

  // Construct full name from name and surname
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

                bool isSelected = _selectedMembers.any((m) =>
                m['employee_id'] ==
                    member['employee_id']);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: imageUrl != null &&
                        imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
                    value: isSelected,
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
