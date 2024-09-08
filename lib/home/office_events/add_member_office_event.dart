import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddMemberPage extends StatefulWidget {
  const AddMemberPage({Key? key}) : super(key: key);

  @override
  _AddMemberPageState createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  List<Map<String, dynamic>> _selectedMembers = [];

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
        'Authorization': 'Bearer $token',  // Pass the token in the headers
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
          'img_name': item['img_name'],  // Add img_name for profile picture
        }).toList();
        _filteredMembers = _members;
      });
    } else {
      throw Exception('Failed to load members');
    }
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
    Navigator.pop(context, _selectedMembers); // Pass the selected members back
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          automaticallyImplyLeading: false, // Remove default back button
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: const Text('Add Member', style: TextStyle(color: Colors.black)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: Column(
        children: [
          // Selected Members Display
          if (_selectedMembers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMembers.length,
                itemBuilder: (context, index) {
                  final member = _selectedMembers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(
                          'https://demo-application-api.flexiflows.co/images/${member['img_name']}'),
                      radius: 25,
                    ),
                  );
                },
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
                  borderRadius: BorderRadius.circular(10.0),
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
                return CheckboxListTile(
                  title: Text('${member['name']} ${member['surname']}'),
                  subtitle: Text(member['email']),
                  value: _selectedMembers.contains(member),
                  secondary: CircleAvatar(
                    backgroundImage: NetworkImage(
                        'https://demo-application-api.flexiflows.co/images/${member['img_name']}'),
                    radius: 20,
                  ),
                  onChanged: (bool? selected) {
                    _onMemberSelected(selected, member);
                  },
                );
              },
            ),
          ),
          // Add Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _onAddButtonPressed, // Pass selected members when clicking Add
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[700],
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 15.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
              child: const Text(
                '+ Add',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
