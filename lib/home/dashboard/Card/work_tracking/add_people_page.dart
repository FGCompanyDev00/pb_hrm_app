import 'package:flutter/material.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';

class AddPeoplePage extends StatefulWidget {
  final String projectId;

  const AddPeoplePage({super.key, required this.projectId});

  @override
  _AddPeoplePageState createState() => _AddPeoplePageState();
}

class _AddPeoplePageState extends State<AddPeoplePage> {
  List<Map<String, dynamic>> _employees = [];
  final List<Map<String, dynamic>> _selectedPeople = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final employees = await WorkTrackingService().getAllEmployees();
      setState(() {
        _employees = employees.map((employee) {
          return {
            ...employee,
            'isAdmin': employee['isAdmin'] ?? false, // Ensure isAdmin is not null
            'isSelected': false,
          };
        }).toList();
      });
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addMembersToProject() async {
    if (_selectedPeople.length < 3) {
      _showErrorDialog('Please select at least three project members, including yourself.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final members = _selectedPeople.map((p) => {
        'id': p['id'],
        'isAdmin': p['isAdmin'] ?? false,
      }).toList();

      await WorkTrackingService().addMembersToProject(widget.projectId, members);

      _showSuccessDialog(); // Show success message and navigate to work tracking page
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Your project members have been successfully added.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkTrackingPage(
                    highlightedProjectId: widget.projectId,
                  ),
                ),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(Map<String, dynamic> employee) {
    setState(() {
      employee['isSelected'] = !(employee['isSelected'] ?? false);
      if (employee['isSelected']) {
        _selectedPeople.add(employee);
      } else {
        _selectedPeople.removeWhere((e) => e['id'] == employee['id']);
      }
    });
  }

  void _toggleAdmin(Map<String, dynamic> employee) {
    setState(() {
      employee['isAdmin'] = !(employee['isAdmin'] ?? false);
    });
  }

  void _filterEmployees(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<Map<String, dynamic>> _getFilteredEmployees() {
    if (_searchQuery.isEmpty) return _employees;
    return _employees
        .where((employee) =>
    employee['name'].toLowerCase().contains(_searchQuery) ||
        employee['email'].toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _getFilteredEmployees();

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
            icon: const Icon(Icons.check, color: Colors.black),
            onPressed: _isLoading ? null : _addMembersToProject,
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
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _selectedPeople[index]['image'] != null
                                ? NetworkImage(_selectedPeople[index]['image'])
                                : null, // Use image if available
                            child: _selectedPeople[index]['image'] == null
                                ? const Icon(Icons.person, size: 30, color: Colors.white)
                                : null, // Display default icon if no image
                          ),
                          if (_selectedPeople[index]['isAdmin'] == true)
                            const Positioned(
                              top: 0,
                              right: 0,
                              child: Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                            ),
                        ],
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
                    onChanged: _filterEmployees,
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
              ],
            ),
            const SizedBox(height: 16),
            // Members List
            Expanded(
              child: ListView.builder(
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final employee = filteredEmployees[index];
                  final isSelected = employee['isSelected'] ?? false;
                  final isAdmin = employee['isAdmin'] ?? false;

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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            _toggleSelection(employee);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            isAdmin ? Icons.star : Icons.star_border,
                            color: isAdmin ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () => _toggleAdmin(employee),
                        ),
                      ],
                    ),
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
