import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_project.dart';

class AddPeoplePage extends StatefulWidget {
  const AddPeoplePage({super.key});

  @override
  _AddPeoplePageState createState() => _AddPeoplePageState();
}

class _AddPeoplePageState extends State<AddPeoplePage> {
  final List<Map<String, dynamic>> _members = [
    {
      'name': 'Alanlove',
      'role': 'Travel Blogger',
      'email': 'alan@psvb.com.la',
      'isAdmin': false,
      'isSelected': false,
      'image': 'assets/avatar_placeholder.png'
    },
    {
      'name': 'Charlotte',
      'role': 'Chief Travel',
      'email': 'charlotte@psvb.com.la',
      'isAdmin': true,
      'isSelected': false,
      'image': 'assets/avatar_placeholder.png'
    },
    {
      'name': 'Evangeline',
      'role': 'Chief Travel',
      'email': 'evangeline@psvb.com.la',
      'isAdmin': true,
      'isSelected': false,
      'image': 'assets/avatar_placeholder.png'
    },
    {
      'name': 'Geraldine',
      'role': 'Private tour',
      'email': 'geraldine@psvb.com.la',
      'isAdmin': false,
      'isSelected': false,
      'image': 'assets/avatar_placeholder.png'
    },
    {
      'name': 'Prudence',
      'role': 'Travel',
      'email': 'prudence@psvb.com.la',
      'isAdmin': false,
      'isSelected': false,
      'image': 'assets/avatar_placeholder.png'
    },
  ];

  String _searchQuery = '';

  void _toggleAdmin(int index) {
    setState(() {
      _members[index]['isAdmin'] = !_members[index]['isAdmin'];
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      _members[index]['isSelected'] = !_members[index]['isSelected'];
    });
  }

  void _addMembers() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Members Added'),
          content: const Text('Members have been added successfully to this project.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.pop(context); // Close the add people page
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => AddProjectPage(onAddProject: (project) {})),
                ); // Navigate back to AddProjectPage
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _members.where((member) {
      return member['name'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Image.asset(
          'assets/background.png',
          fit: BoxFit.cover,
        ),
        title: const Text(
          'Add Member',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 70.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: AssetImage(filteredMembers[index]['image']),
                          ),
                          title: Text(filteredMembers[index]['name']),
                          subtitle: Text('${filteredMembers[index]['role']} ${filteredMembers[index]['email']}'),
                          trailing: Wrap(
                            spacing: 12, // space between two icons
                            children: <Widget>[
                              Checkbox(
                                value: filteredMembers[index]['isSelected'],
                                onChanged: (bool? value) {
                                  _toggleSelection(index);
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  filteredMembers[index]['isAdmin'] ? Icons.star : Icons.star_border,
                                  color: filteredMembers[index]['isAdmin'] ? Colors.amber : Colors.grey,
                                ),
                                onPressed: () {
                                  _toggleAdmin(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16.0,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 120,
                child: ElevatedButton.icon(
                  onPressed: _addMembers,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
