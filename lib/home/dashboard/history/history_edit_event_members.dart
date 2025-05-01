import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EditEventMembersPage extends StatefulWidget {
  final String id;
  final String type;

  const EditEventMembersPage({
    super.key,
    required this.id,
    required this.type,
  });

  @override
  _EditEventMembersPageState createState() => _EditEventMembersPageState();
}

class _EditEventMembersPageState extends State<EditEventMembersPage> {
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> filteredMembers = [];
  List<Map<String, dynamic>> selectedMembers = [];
  final TextEditingController searchController = TextEditingController();
  Set<String> excludedMemberIds = {};

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? currentUserId = prefs.getString('employee_id'); // Get current user id

      if (token == null || currentUserId == null) {
        print('No token or employee id found in SharedPreferences.');
        return;
      }

      // Fetch meeting or car members based on the widget.type
      if (widget.type == "meeting") {
        await _fetchMeetingMembers(currentUserId, token);
      } else if (widget.type == "car") {
        await _fetchCarMembers(currentUserId, token);
      }

      // Fetch members from the main API
      final Uri url = Uri.parse('$baseUrl/api/work-tracking/project-member/get-all-employees');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['statusCode'] == 200 && data['results'] is List) {
          List results = data['results'];

          // Filter out the current user and the already added members from meeting or car
          List<Map<String, dynamic>> membersFromApi = results
              .where((item) => item['employee_id'] != currentUserId && !excludedMemberIds.contains(item['employee_id']))
              .map<Map<String, dynamic>>((item) {
            return {
              'name': '${item['name']} ${item['surname']}',
              'email': item['email'] ?? '',
              'img': item['img_name'] ?? '',
              'selected': false,
            };
          }).toList();

          setState(() {
            members = membersFromApi;
            filteredMembers = membersFromApi;
          });
        }
      } else {
        print('Failed to load members');
      }
    } catch (error) {
      print('Error fetching members: $error');
    }
  }

  // Fetch meeting members and add them to the exclusion list
  Future<void> _fetchMeetingMembers(String currentUserId, String token) async {
    final Uri url = Uri.parse('$baseUrl/api/work-tracking/meeting/get-meeting/${widget.id}');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['statusCode'] == 200 && data['result'][0]['members'] is List) {
        List meetingMembers = data['result'][0]['members'];
        setState(() {
          excludedMemberIds.addAll(meetingMembers.map((member) => member['employee_id']));
        });
      }
    } else {
      print('Failed to load meeting members');
    }
  }

  // Fetch car members and add them to the exclusion list
  Future<void> _fetchCarMembers(String currentUserId, String token) async {
    final Uri url = Uri.parse('$baseUrl/api/office-administration/car_permit/me/${widget.id}');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['statusCode'] == 200 && data['results']['members'] is List) {
        List carMembers = data['results']['members'];
        setState(() {
          excludedMemberIds.addAll(carMembers.map((member) => member['member_id']));
        });
      }
    } else {
      // If the first API fails, try the second approach.
      final secondUrl = Uri.parse('$baseUrl/api/office-administration/car_permit/invite-car-member/${widget.id}');
      final secondResponse = await http.get(
        secondUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (secondResponse.statusCode == 200) {
        final data = json.decode(secondResponse.body);
        if (data['statusCode'] == 200 && data['results']['members'] is List) {
          List carMembers = data['results']['members'];
          setState(() {
            excludedMemberIds.addAll(carMembers.map((member) => member['member_id']));
          });
        }
      } else {
        print('Failed to load car members');
      }
    }
  }

  void _filterMembers(String query) {
    setState(() {
      filteredMembers = members.where((member) {
        final name = member['name'].toLowerCase();
        final email = member['email'].toLowerCase();
        return name.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.addPeople,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
              ),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30.0),
              bottomRight: Radius.circular(30.0),
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: Stack(
                      children: [
                        for (int i = 0; i < selectedMembers.take(4).length; i++)
                          Positioned(
                            left: i * 30.0,
                            child: CircleAvatar(
                              backgroundImage: selectedMembers[i]['img'] != ''
                                  ? NetworkImage(selectedMembers[i]['img'])
                                  : const AssetImage('assets/avatar_placeholder.png')
                              as ImageProvider,
                              radius: 20,
                            ),
                          ),
                        if (selectedMembers.length > 4)
                          Positioned(
                            left: 4 * 30.0,
                            child: CircleAvatar(
                              backgroundColor: Colors.grey,
                              radius: 20,
                              child: Text(
                                '+${selectedMembers.length - 4}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Filter only selected members to pass back
                    List<Map<String, dynamic>> selectedMembersToReturn = selectedMembers
                        .map((member) => {
                      'employee_id': member['employee_id'],
                      'name': member['name'],
                      'img_name': member['img'],
                    })
                        .toList();

                    // Return selected members to previous page
                    Navigator.pop(context, selectedMembersToReturn);
                  },
                  icon: Icon(
                    Icons.add,
                    size: 24,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  label: const Text(
                    'Add',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.green : const Color(0xFFDBB342),
                    foregroundColor: isDarkMode ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              onChanged: _filterMembers,
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredMembers.length,
                itemBuilder: (context, index) {
                  final member = filteredMembers[index];
                  return Column(
                    children: [
                      ListTile(
                        leading: Checkbox(
                          value: member['selected'],
                          onChanged: (value) {
                            setState(() {
                              member['selected'] = value!;
                              if (value) {
                                selectedMembers.add(member);
                              } else {
                                selectedMembers.remove(member);
                              }
                            });
                          },
                        ),
                        title: Text(member['name']),
                        subtitle: Text(member['email']),
                        trailing: CircleAvatar(
                          backgroundImage: member['img'] != ''
                              ? NetworkImage(member['img'])
                              : const AssetImage('assets/avatar_placeholder.png')
                          as ImageProvider,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 16),
                        height: 1,
                        color: Colors.grey[300],
                        width: MediaQuery.of(context).size.width * 0.8,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
