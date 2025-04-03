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
  final workTrackingService = WorkTrackingService();

  // New variables for groups
  List<Map<String, dynamic>> _groups = [];

  // To track members to be deleted and added
  final Set<String> _membersToDelete = {};
  final List<Map<String, dynamic>> _membersToAdd = [];

  @override
  void initState() {
    super.initState();
    debugPrint(
        'EditPeoplePage initialized with project ID: ${widget.projectId}');
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First fetch employees
      await _fetchEmployees();
      // Then fetch existing members
      await _fetchExistingProjectMembers();
      // Finally fetch groups
      await _fetchGroups();
    } catch (e) {
      debugPrint('Error during initialization: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update _fetchEmployees to return Future
  Future<void> _fetchEmployees() async {
    debugPrint('Fetching employees from WorkTrackingService...');
    try {
      final employees = await WorkTrackingService().getAllEmployees();
      debugPrint(
          'Employees fetched successfully. Total employees: ${employees.length}');

      setState(() {
        _employees = employees.map((employee) {
          return {
            ...employee,
            'isAdmin': false,
            'isSelected': false,
            'isExisting': false,
            'member_id': '',
            'img_name': employee['img_name'] ?? '',
          };
        }).toList();
      });
      debugPrint('Employees processed and ready for display.');
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      throw e;
    }
  }

  // Update _fetchExistingProjectMembers to properly update state
  Future<void> _fetchExistingProjectMembers() async {
    debugPrint('Fetching existing project members...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse(
            '${workTrackingService.baseUrl}/api/work-tracking/proj/find-Member-By-ProjectId/${widget.projectId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
          'Existing Members API Response Status Code: ${response.statusCode}');
      debugPrint('Existing Members API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200) {
          final members = data['Members'];
          if (members == null) {
            debugPrint('No existing members found for this project.');
            return;
          }

          List<dynamic> existingMembers = members;
          debugPrint(
              'Existing members fetched successfully. Total existing members: ${existingMembers.length}');

          // Clear selected people first
          _selectedPeople.clear();

          for (var existing in existingMembers) {
            String employeeId = existing['employee_id'];
            String memberId = existing['member_id'];
            bool isAdmin = existing['member_status'] == '1';

            // Find and update employee in the list
            int index = _employees
                .indexWhere((emp) => emp['employee_id'] == employeeId);
            if (index != -1) {
              setState(() {
                _employees[index]['isSelected'] = true;
                _employees[index]['isAdmin'] = isAdmin;
                _employees[index]['isExisting'] = true;
                _employees[index]['member_id'] = memberId;

                // Add to selected people
                _selectedPeople.add(_employees[index]);
              });
              debugPrint(
                  'Updated existing member: ${_employees[index]['name']}, Admin: $isAdmin');
            }
          }
        }
      } else {
        throw Exception('Failed to fetch existing members');
      }
    } catch (e) {
      debugPrint('Error fetching existing members: $e');
      throw e;
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
        _showDialog(
            'Error', 'Authentication token not found. Please log in again.');
        return;
      }
      debugPrint('Retrieved Bearer Token for groups: $token');

      final response = await http.get(
        Uri.parse(
            '${workTrackingService.baseUrl}/api/work-tracking/group/usergroups'),
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
          debugPrint(
              'Groups fetched successfully. Total groups: ${_groups.length}');
        } else {
          debugPrint(
              'Failed to fetch groups. Response message: ${data['message']}');
          _showDialog('Error', 'Failed to fetch groups. Please try again.');
        }
      } else {
        debugPrint(
            'Failed to fetch groups. Status Code: ${response.statusCode}');
        _showDialog('Error', 'Failed to fetch groups. Please try again.');
      }
    } catch (e) {
      debugPrint('Exception occurred while fetching groups: $e');
      _showDialog('Error',
          'An error occurred while fetching groups. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Group fetching process completed.');
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
        _showDialog(
            'Error', 'Authentication token not found. Please log in again.');
        return;
      }

      // Handle deletions first
      for (String memberId in _membersToDelete) {
        debugPrint('Deleting member with ID: $memberId');
        final deleteResponse = await http.put(
          Uri.parse(
              '${workTrackingService.baseUrl}/api/work-tracking/project-member/delete/$memberId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        debugPrint(
            'Delete Member API Response Status Code: ${deleteResponse.statusCode}');
        debugPrint('Delete Member API Response Body: ${deleteResponse.body}');

        // Accept 200, 201, 202, 204 as success status codes
        if (deleteResponse.statusCode < 200 ||
            deleteResponse.statusCode > 204) {
          debugPrint('Failed to delete member with ID: $memberId');
          _showDialog(
              'Error', 'Failed to delete some members. Please try again.');
          return;
        } else {
          debugPrint('Successfully deleted member with ID: $memberId');
        }
      }

      // Handle additions/updates
      if (_membersToAdd.isNotEmpty) {
        Map<String, dynamic> requestBody = {
          'project_id': widget.projectId,
          'employees_member': _membersToAdd,
        };

        debugPrint(
            'Request Body for Adding/Updating Members: ${jsonEncode(requestBody)}');

        final postResponse = await http.post(
          Uri.parse(
              '${workTrackingService.baseUrl}/api/work-tracking/project-member/insert'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(requestBody),
        );

        debugPrint(
            'Add/Update Members API Response Status Code: ${postResponse.statusCode}');
        debugPrint(
            'Add/Update Members API Response Body: ${postResponse.body}');

        // Parse response body to check actual status code
        final responseData = jsonDecode(postResponse.body);
        final responseStatusCode = responseData['statusCode'];

        // Check for conflict status in response body
        if (responseStatusCode == 409) {
          // Handle conflict - member already exists
          final conflictingMembers = responseData['values'] as List;
          final conflictingIds =
              conflictingMembers.map((m) => m['employee_id']).join(', ');
          _showDialog(
            'Warning',
            'Some members are already part of another project: $conflictingIds\nPlease remove these members and try again.',
          );
          return;
        }
        // Check if HTTP status code is in success range but response status is not
        else if ((postResponse.statusCode >= 200 &&
                postResponse.statusCode <= 204) &&
            responseStatusCode != 200 &&
            responseStatusCode != 201) {
          debugPrint(
              'Failed to add/update members. Response status: $responseStatusCode');
          _showDialog('Error',
              'Failed to add/update members: ${responseData['message']}');
          return;
        }
        // Check if HTTP status code itself is an error
        else if (postResponse.statusCode < 200 ||
            postResponse.statusCode > 204) {
          debugPrint(
              'Failed to add/update members. HTTP status: ${postResponse.statusCode}');
          _showDialog(
              'Error', 'Failed to add/update members. Please try again.');
          return;
        } else {
          debugPrint('Successfully added/updated members.');
        }
      }

      // Show success dialog with more engaging UI
      _showSuccessDialog('Project members updated successfully');
    } catch (e) {
      debugPrint('Exception occurred while updating members: $e');
      _showDialog('Error',
          'An error occurred while updating members. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Update project members process completed.');
    }
  }

  // Add new method for success dialog with better UI
  void _showSuccessDialog(String message) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
                const SizedBox(height: 20),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.green[300] : Colors.green[700],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDBB342),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Return to previous screen with updated data
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkTrackingPage(
                            highlightedProjectId: widget.projectId,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                debugPrint(
                    'Navigating to WorkTrackingPage with highlighted project ID: ${widget.projectId}');
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
      return;
    }
    setState(() {
      bool currentlySelected = employee['isSelected'] ?? false;
      employee['isSelected'] = !currentlySelected;

      if (employee['isSelected']) {
        // Adding a member
        if (!_selectedPeople
            .any((e) => e['employee_id'] == employee['employee_id'])) {
          _selectedPeople.add(employee);
          debugPrint('Selected member: ${employee['name']}');

          if (!employee['isExisting']) {
            // New member being added
            _membersToAdd.add({
              'employee_id': employee['employee_id'],
              'member_status': employee['isAdmin'] ? '1' : '0',
            });
            debugPrint('Added to _membersToAdd: ${employee['name']}');
          }
        }
      } else {
        // Removing a member
        _selectedPeople
            .removeWhere((e) => e['employee_id'] == employee['employee_id']);
        debugPrint('Deselected member: ${employee['name']}');

        if (employee['isExisting']) {
          // Existing member being removed
          _membersToDelete.add(employee['member_id']);
          debugPrint('Added to _membersToDelete: ${employee['member_id']}');
        }

        // Remove from _membersToAdd if it was newly added but now deselected
        _membersToAdd
            .removeWhere((e) => e['employee_id'] == employee['employee_id']);
      }
    });
  }

  // Toggle admin status with handling for updates
  void _toggleAdmin(Map<String, dynamic> employee) {
    if (_isLoading) {
      debugPrint('Cannot toggle admin status while loading.');
      return;
    }
    setState(() {
      bool currentlyAdmin = employee['isAdmin'] ?? false;
      employee['isAdmin'] = !currentlyAdmin;
      debugPrint(
          '${employee['isAdmin'] ? 'Granted' : 'Revoked'} admin rights for: ${employee['name']}');

      if (employee['isExisting']) {
        // Update existing member's admin status
        if (employee['isSelected']) {
          // If still selected, update their status
          int index = _membersToAdd
              .indexWhere((e) => e['employee_id'] == employee['employee_id']);
          if (index != -1) {
            _membersToAdd[index]['member_status'] =
                employee['isAdmin'] ? '1' : '0';
          } else {
            _membersToAdd.add({
              'employee_id': employee['employee_id'],
              'member_status': employee['isAdmin'] ? '1' : '0',
            });
          }
        }
      } else if (employee['isSelected']) {
        // Update new member's admin status
        int index = _membersToAdd
            .indexWhere((e) => e['employee_id'] == employee['employee_id']);
        if (index != -1) {
          _membersToAdd[index]['member_status'] =
              employee['isAdmin'] ? '1' : '0';
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
    final filtered = _employees
        .where((employee) =>
            (employee['name']?.toLowerCase().contains(_searchQuery) ?? false) ||
            (employee['email']?.toLowerCase().contains(_searchQuery) ?? false))
        .toList();
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
              image: AssetImage(
                  isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: false,
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
        actions: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, color: Colors.black, size: 20),
              label: const Text(
                'Update',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _isLoading ? null : _updateProjectMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDBB342),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
          ),
        ],
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  // Selected Members Preview
                  _buildSelectedMembersPreview(),
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
                              _searchQuery.isEmpty
                                  ? 'No employees found.'
                                  : 'No employees match your search.',
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
                              final isSelected =
                                  employee['isSelected'] ?? false;
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
                                    _buildMemberAvatar(employee),
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
                                  tooltip:
                                      isAdmin ? 'Revoke Admin' : 'Grant Admin',
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

  Widget _buildMemberAvatar(Map<String, dynamic> member) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.grey[300],
          backgroundImage:
              member['img_name'] != null && member['img_name'].isNotEmpty
                  ? CachedNetworkImageProvider(member['img_name'])
                  : null,
          child: member['img_name'] == null || member['img_name'].isEmpty
              ? const Icon(Icons.person, size: 30, color: Colors.white)
              : null,
        ),
        if (member['isAdmin'] == true)
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
    );
  }

  Widget _buildSelectedMembersPreview() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedPeople.length + (_selectedPeople.isEmpty ? 0 : 1),
        itemBuilder: (context, index) {
          if (index < _selectedPeople.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _buildMemberAvatar(_selectedPeople[index]),
            );
          } else {
            return Padding(
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
            );
          }
        },
      ),
    );
  }
}
