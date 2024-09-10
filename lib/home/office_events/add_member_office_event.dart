import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddMemberPage extends StatefulWidget {
  const AddMemberPage({super.key});

  @override
  _AddMemberPageState createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  final List<Map<String, dynamic>> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/project-member/get-all-employees'),
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
  }

  Future<String?> _fetchProfileImage(String employeeId) async {
    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['results'];
      return data['images'];
    }
    return null;
  }

  void _onMemberSelected(bool? selected, Map<String, dynamic> member) {
    setState(() {
      if (selected == true) {
        _selectedMembers.add(member);
      } else {
        _selectedMembers.remove(member);
      }
    });
  }

  void _onAddButtonPressed() {
    Navigator.pop(context, _selectedMembers);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Image.asset(
          'assets/background.png',
          fit: BoxFit.cover,
        ),
        title: const Text(
          'Add Member',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Selected Members Display with the Add Button next to it
          if (_selectedMembers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              height: 80,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedMembers.length > 3 ? 3 : _selectedMembers.length,
                      itemBuilder: (context, index) {
                        final member = _selectedMembers[index];
                        return FutureBuilder<String?>(
                          future: _fetchProfileImage(member['employee_id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: CircleAvatar(
                                  backgroundImage: snapshot.data != null
                                      ? NetworkImage(snapshot.data!)
                                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
                        child: Text('+${_selectedMembers.length - 3}', style: const TextStyle(color: Colors.black)),
                      ),
                    ),
                  // Add Button aligned with Figma design
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: ElevatedButton(
                      onPressed: _onAddButtonPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[700],
                        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 15.0),
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
          // Search Box
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
                  borderRadius: BorderRadius.circular(30.0),  // Rounded search box
                ),
              ),
            ),
          ),
          // Member List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredMembers.length,
              itemBuilder: (context, index) {
                final member = _filteredMembers[index];
                return ListTile(
                  leading: FutureBuilder<String?>(
                    future: _fetchProfileImage(member['employee_id']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                        return CircleAvatar(
                          backgroundImage: snapshot.data != null
                              ? NetworkImage(snapshot.data!)
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
                    value: _selectedMembers.contains(member),
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
