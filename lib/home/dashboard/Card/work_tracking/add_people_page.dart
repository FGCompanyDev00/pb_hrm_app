import 'package:flutter/material.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';

class AddPeoplePage extends StatefulWidget {
  final List<Map<String, dynamic>> selectedPeople;

  const AddPeoplePage({Key? key, required this.selectedPeople}) : super(key: key);

  @override
  _AddPeoplePageState createState() => _AddPeoplePageState();
}

class _AddPeoplePageState extends State<AddPeoplePage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _selectedPeople = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedPeople = List.from(widget.selectedPeople);
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final employees = await WorkTrackingService().getAllEmployees();
      setState(() {
        _employees = employees;
      });
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(Map<String, dynamic> employee) {
    setState(() {
      if (_selectedPeople.contains(employee)) {
        _selectedPeople.remove(employee);
      } else {
        _selectedPeople.add(employee);
      }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              Navigator.pop(context, _selectedPeople);
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Selected Members Preview
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedPeople.length + 1,
                      itemBuilder: (context, index) {
                        if (index < _selectedPeople.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _selectedPeople[index]['image'] != null
                                  ? NetworkImage(_selectedPeople[index]['image'])
                                  : null, // Use image if available
                              child: _selectedPeople[index]['image'] == null
                                  ? const Icon(Icons.person, size: 30, color: Colors.white)
                                  : null, // Display default icon if no image
                            ),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[300],
                              child: Text(
                                '+${_selectedPeople.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search Bar and Group Toggle
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search',
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Text('Group'),
                            SizedBox(width: 8),
                            Icon(Icons.list),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Members List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _employees.length,
                      itemBuilder: (context, index) {
                        final employee = _employees[index];
                        final isSelected = _selectedPeople.contains(employee);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            backgroundImage: employee['image'] != null
                                ? NetworkImage(employee['image'])
                                : null, // Use image if available
                            child: employee['image'] == null
                                ? const Icon(Icons.person, size: 24, color: Colors.white)
                                : null, // Display default icon if no image
                          ),
                          title: Text(employee['name']),
                          subtitle: Text(employee['email']),
                          trailing: Icon(
                            Icons.star,
                            color: isSelected ? Colors.amber : Colors.grey,
                          ),
                          onTap: () => _toggleSelection(employee),
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
