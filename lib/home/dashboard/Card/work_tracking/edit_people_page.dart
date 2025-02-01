// lib/home/dashboard/Card/work_tracking/edit_people_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EditPeoplePage extends StatefulWidget {
  final String projectId;

  const EditPeoplePage({super.key, required this.projectId});

  @override
  EditPeoplePageState createState() => EditPeoplePageState();
}

class EditPeoplePageState extends State<EditPeoplePage> {
  List<Map<String, dynamic>> _employees = [];
  final List<Map<String, dynamic>> _selectedPeople = [];
  String _searchQuery = '';
  bool _isLoading = false;

  // New variables for groups
  List<Map<String, dynamic>> _groups = [];

  // To track members to be deleted and added
  final Set<String> _membersToDelete = {};
  final List<Map<String, dynamic>> _membersToAdd = [];

  @override
  void initState() {
    super.initState();
    debugPrint('EditPeoplePage initialized with project ID: ${widget.projectId}');
    _fetchEmployees();
    _fetchGroups(); // Fetch groups on initialization
    _fetchExistingProjectMembers(); // Fetch existing project members
  }

  // Existing method to fetch all employees
  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
    });
    debugPrint('Fetching employees from WorkTrackingService...');
    try {
      final employees = await WorkTrackingService().getAllEmployees();
      debugPrint('Employees fetched successfully. Total employees: ${employees.length}');
      // Ensure that each employee has 'isAdmin' and 'isSelected' properly set
      setState(() {
        _employees = employees.map((employee) {
          return {
            ...employee,
            'isAdmin': employee['isAdmin'] ?? false,
            'isSelected': false,
            'isExisting': false, // Flag to indicate if the member is existing
            'member_id': employee['member_id'] ?? '', // To store member_id if existing
          };
        }).toList();
      });
      debugPrint('Employees processed and ready for display.');
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      _showDialog('Error', 'Failed to fetch employees. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Employee fetching process completed.');
    }
  }

  // New method to fetch groups from the API
  Future<void> _fetchGroups() async {
    setState(() {
      _isLoading = true;
    });
    debugPrint('Fetching groups from API...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        debugPrint('No token found in SharedPreferences.');
        _showDialog('Error', 'Authentication token not found. Please log in again.');
        return;
      }
      debugPrint('Retrieved Bearer Token for groups: $token');

      final response = await http.get(
        Uri.parse('${WorkTrackingService.baseUrl}/api/work-tracking/group/usergroups'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Groups API Response Status Code: ${response.statusCode}');
      debugPrint('Groups API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] != null) {
          setState(() {
            _groups = List<Map<String, dynamic>>.from(data['results']);
          });
          debugPrint('Groups fetched successfully. Total groups: ${_groups.length}');
        } else {
          debugPrint('Failed to fetch groups. Response message: ${data['message']}');
          _showDialog('Error', 'Failed to fetch groups. Please try again.');
        }
      } else {
        debugPrint('Failed to fetch groups. Status Code: ${response.statusCode}');
        _showDialog('Error', 'Failed to fetch groups. Please try again.');
      }
    } catch (e) {
      debugPrint('Exception occurred while fetching groups: $e');
      _showDialog('Error', 'An error occurred while fetching groups. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Group fetching process completed.');
    }
  }

  // New method to fetch existing project members
  // New method to fetch existing project members
  Future<void> _fetchExistingProjectMembers() async {
    setState(() {
      _isLoading = true;
    });
    debugPrint('Fetching existing project members...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        debugPrint('No token found in SharedPreferences.');
        _showDialog('Error', 'Authentication token not found. Please log in again.');
        return;
      }

      final response = await http.get(
        Uri.parse('${WorkTrackingService.baseUrl}/api/work-tracking/proj/find-Member-By-ProjectId/${widget.projectId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Existing Members API Response Status Code: ${response.statusCode}');
      debugPrint('Existing Members API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['Members'] != null) {
          List<dynamic> existingMembers = data['Members'];
          debugPrint('Existing members fetched successfully. Total existing members: ${existingMembers.length}');

          setState(() {
            for (var existing in existingMembers) {
              String employeeId = existing['employee_id'];
              String memberId = existing['member_id']; // Assuming 'member_id' is returned
              bool isAdmin = existing['member_status'] == '1';

              // Find the employee in the _employees list
              int index = _employees.indexWhere((emp) => emp['employee_id'] == employeeId);
              if (index != -1) {
                _employees[index]['isSelected'] = true;
                _employees[index]['isAdmin'] = isAdmin;
                _employees[index]['isExisting'] = true;
                _employees[index]['member_id'] = memberId;
                _selectedPeople.add(_employees[index]);
              } else {
                // If employee not found in the main list, you might want to handle it
                debugPrint('Employee with ID $employeeId not found in the employees list.');
              }
            }
          });
        } else {
          debugPrint('Failed to fetch existing members. Response message: ${data['message']}');
          _showDialog('Error', 'Failed to fetch existing members. Please try again.');
        }
      } else {
        debugPrint('Failed to fetch existing members. Status Code: ${response.statusCode}');
        _showDialog('Error', 'Failed to fetch existing members. Please try again.');
      }
    } catch (e) {
      debugPrint('Exception occurred while fetching existing members: $e');
      _showDialog('Error', 'An error occurred while fetching existing members. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Existing members fetching process completed.');
    }
  }

  // Method to add or update members
  Future<void> _updateProjectMembers() async {
    debugPrint('Attempting to update project members...');
    if (_isLoading) {
      debugPrint('Already loading. Please wait.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        debugPrint('No token found in SharedPreferences.');
        _showDialog('Error', 'Authentication token not found. Please log in again.');
        return;
      }
      debugPrint('Retrieved Bearer Token: $token');

      // Handle deletions
      for (String memberId in _membersToDelete) {
        final deleteResponse = await http.put(
          Uri.parse('${WorkTrackingService.baseUrl}/api/work-tracking/project-member/delete/$memberId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        debugPrint('Delete Member API Response Status Code: ${deleteResponse.statusCode}');
        debugPrint('Delete Member API Response Body: ${deleteResponse.body}');

        if (deleteResponse.statusCode != 200 && deleteResponse.statusCode != 204) {
          debugPrint('Failed to delete member with ID: $memberId');
          _showDialog('Error', 'Failed to delete some members. Please try again.');
          return;
        } else {
          debugPrint('Member with ID $memberId deleted successfully.');
        }
      }

      // Prepare list of members to add or update
      List<Map<String, dynamic>> employeesMember = _membersToAdd.map((person) {
        String memberStatus = person['isAdmin'] ? '1' : '0';
        debugPrint('Employee ID: ${person['employee_id']}, Member Status: $memberStatus');
        return {
          'employee_id': person['employee_id'],
          'member_status': memberStatus,
        };
      }).toList();

      if (employeesMember.isNotEmpty) {
        Map<String, dynamic> requestBody = {
          'project_id': widget.projectId,
          'employees_member': employeesMember,
        };

        debugPrint('Request Body for Adding Members: ${jsonEncode(requestBody)}');

        // Make the POST request to add/update members
        final postResponse = await http.post(
          Uri.parse('${WorkTrackingService.baseUrl}/api/work-tracking/project-member/insert'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(requestBody),
        );

        debugPrint('Add Members API Response Status Code: ${postResponse.statusCode}');
        debugPrint('Add Members API Response Body: ${postResponse.body}');

        if (postResponse.statusCode != 200 && postResponse.statusCode != 201) {
          debugPrint('Failed to add/update members.');
          _showDialog('Error', 'Failed to add/update members. Please try again.');
          return;
        } else {
          debugPrint('Members added/updated successfully.');
        }
      }

      // Show success dialog
      _showDialog('Success', 'Project members have been successfully updated.', isSuccess: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Exception occurred while updating members: $e');
      }
      _showDialog('Error', 'An error occurred while updating members. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Update project members process completed.');
    }
  }

  // Dialog method remains the same
  void _showDialog(String title, String message, {bool isSuccess = false}) {
    debugPrint('$title Dialog: $message');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('Dialog "$title" dismissed.');
              Navigator.of(context).pop();
              if (isSuccess) {
                debugPrint('Navigating to WorkTrackingPage with highlighted project ID: ${widget.projectId}');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkTrackingPage(
                      highlightedProjectId: widget.projectId,
                    ),
                  ),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Toggle selection with handling for add/remove
  void _toggleSelection(Map<String, dynamic> employee) {
    if (_isLoading) {
      debugPrint('Cannot toggle selection while loading.');
      return; // Disable toggling if API call is in progress
    }
    setState(() {
      bool currentlySelected = employee['isSelected'] ?? false;
      employee['isSelected'] = !currentlySelected;
      if (employee['isSelected']) {
        // Prevent adding duplicates
        if (!_selectedPeople.any((e) => e['employee_id'] == employee['employee_id'])) {
          _selectedPeople.add(employee);
          debugPrint('Selected member: ${employee['name']}');

          if (!employee['isExisting']) {
            _membersToAdd.add(employee);
            debugPrint('Added to _membersToAdd: ${employee['name']}');
          }
        }
      } else {
        _selectedPeople.removeWhere((e) => e['employee_id'] == employee['employee_id']);
        debugPrint('Deselected member: ${employee['name']}');

        if (employee['isExisting']) {
          _membersToDelete.add(employee['member_id']);
          debugPrint('Added to _membersToDelete: ${employee['name']}');
        }

        // Remove from _membersToAdd if it was newly added but now deselected
        _membersToAdd.removeWhere((e) => e['employee_id'] == employee['employee_id']);
      }
    });
  }

  // Toggle admin status with handling for updates
  void _toggleAdmin(Map<String, dynamic> employee) {
    if (_isLoading) {
      debugPrint('Cannot toggle admin status while loading.');
      return; // Prevent toggling if API call is in progress
    }
    setState(() {
      bool currentlyAdmin = employee['isAdmin'] ?? false;
      employee['isAdmin'] = !currentlyAdmin;
      debugPrint('${employee['isAdmin'] ? 'Granted' : 'Revoked'} admin rights for: ${employee['name']}');

      if (employee['isExisting']) {
        // Update member_status in _membersToAdd
        int index = _membersToAdd.indexWhere((e) => e['employee_id'] == employee['employee_id']);
        if (index != -1) {
          _membersToAdd[index]['isAdmin'] = employee['isAdmin'];
        } else {
          // If not in _membersToAdd, add it for updating
          _membersToAdd.add(employee);
        }
      } else {
        // For newly added members, ensure member_status is updated in _membersToAdd
        int index = _membersToAdd.indexWhere((e) => e['employee_id'] == employee['employee_id']);
        if (index != -1) {
          _membersToAdd[index]['isAdmin'] = employee['isAdmin'];
        }
      }
    });
  }

  // Filter employees based on search query
  void _filterEmployees(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
    debugPrint('Filtering employees with query: "$query"');
  }

  // Get filtered employees list
  List<Map<String, dynamic>> _getFilteredEmployees() {
    if (_searchQuery.isEmpty) {
      debugPrint('No search query. Displaying all employees.');
      return _employees;
    }
    final filtered = _employees.where((employee) => (employee['name']?.toLowerCase().contains(_searchQuery) ?? false) || (employee['email']?.toLowerCase().contains(_searchQuery) ?? false)).toList();
    debugPrint('Filtered employees count: ${filtered.length}');
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final filteredEmployees = _getFilteredEmployees();

    return Scaffold(
      appBar: AppBar(
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
        centerTitle: true,
        title: Text(
          'Edit Members',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () {
            debugPrint('Back button pressed.');
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.black),
            onPressed: _isLoading
                ? () {
                    debugPrint('Update Members button pressed but currently loading. Action is disabled.');
                  }
                : _updateProjectMembers,
            tooltip: 'Update Project Members',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  // Selected Members Preview
                  SizedBox(
                    height: 50,
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
                                  radius: 26,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _selectedPeople[index]['img_name'] != null && _selectedPeople[index]['img_name'].isNotEmpty ? NetworkImage(_selectedPeople[index]['img_name']) : null,
                                  child: _selectedPeople[index]['img_name'] == null || _selectedPeople[index]['img_name'].isEmpty ? const Icon(Icons.person, size: 30, color: Colors.white) : null,
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
                          return Transform.translate(
                            offset: const Offset(0, 0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  '+${_selectedPeople.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  Expanded(
                    child: filteredEmployees.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty ? 'No employees found.' : 'No employees match your search.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredEmployees.length,
                            itemBuilder: (context, index) {
                              final employee = filteredEmployees[index];
                              final isSelected = employee['isSelected'] ?? false;
                              final isAdmin = employee['isAdmin'] ?? false;

                              return ListTile(
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        _toggleSelection(employee);
                                      },
                                    ),
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: employee['img_name'] != null && employee['img_name'].isNotEmpty ? CachedNetworkImageProvider(employee['img_name']) : null,
                                      child: employee['img_name'] == null || employee['img_name'].isEmpty ? const Icon(Icons.person, size: 24, color: Colors.white) : null,
                                    ),
                                  ],
                                ),
                                title: Text(
                                  employee['name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(employee['email'] ?? 'No Email'),
                                trailing: IconButton(
                                  icon: Icon(
                                    isAdmin ? Icons.star : Icons.star_border,
                                    color: isAdmin ? Colors.amber : Colors.grey,
                                  ),
                                  onPressed: () => _toggleAdmin(employee),
                                  tooltip: isAdmin ? 'Revoke Admin' : 'Grant Admin',
                                ),
                                onTap: () => _toggleSelection(employee),
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
    );
  }
}
