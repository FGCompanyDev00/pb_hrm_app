import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_assignment.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

class AssignmentSection extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const AssignmentSection({Key? key, required this.projectId, required this.baseUrl})
      : super(key: key);

  @override
  _AssignmentSectionState createState() => _AssignmentSectionState();
}

class _AssignmentSectionState extends State<AssignmentSection> {
  final WorkTrackingService _workTrackingService = WorkTrackingService();
  List<Map<String, dynamic>> _assignments = [];
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Finished'];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchAssignmentData();
  }

  Future<void> _fetchAssignmentData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final assignments = await _workTrackingService.fetchAssignments(widget.projectId);
      setState(() {
        // Filter assignments to only include those with matching proj_id
        _assignments = assignments.where((assignment) => assignment['proj_id'] == widget.projectId).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load assignments: ${e.toString()}')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  void _navigateToAddAssignment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAssignmentPage(
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _fetchAssignmentData();
      }
    });
  }

  Future<void> _showEditAssignmentModal(Map<String, dynamic> assignment) async {
    TextEditingController titleController = TextEditingController(text: assignment['title']);
    TextEditingController descriptionController =
    TextEditingController(text: assignment['description']);
    String selectedStatus = assignment['s_name'] ?? 'Pending';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)), // Rounded corners
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _buildEditAssignmentContent(
              context, titleController, descriptionController, selectedStatus, assignment),
        );
      },
    );
  }

  Widget _buildEditAssignmentContent(
      BuildContext context,
      TextEditingController titleController,
      TextEditingController descriptionController,
      String selectedStatus,
      Map<String, dynamic> assignment) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20.0),
          margin: const EdgeInsets.only(top: 45.0),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10.0, offset: Offset(0.0, 10.0)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // To make the card compact
            children: [
              const Text(
                'Edit Assignment',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              DropdownButton<String>(
                value: selectedStatus,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedStatus = newValue!;
                  });
                },
                items: ['Pending', 'Processing', 'Finished'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24.0),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      assignment['title'] = titleController.text;
                      assignment['description'] = descriptionController.text;
                      assignment['s_name'] = selectedStatus;
                      // TODO: Make an API call to update the assignment in the backend.
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          left: 20.0,
          right: 20.0,
          child: CircleAvatar(
            backgroundColor: Colors.deepPurple,
            radius: 45.0,
            child: Icon(Icons.edit, size: 50.0, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(String assignmentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Assignment'),
          content: const Text('Are you sure you want to delete this assignment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAssignment(assignmentId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAssignment(String assignmentId) async {
    try {
      await _workTrackingService.deleteAssignment(assignmentId);
      setState(() {
        _assignments.removeWhere((assignment) => assignment['as_id'] == assignmentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete assignment')),
      );
    }
  }

  Future<void> _showViewAssignmentModal(Map<String, dynamic> assignment) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)), // Rounded corners
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _buildViewAssignmentContent(context, assignment),
        );
      },
    );
  }

  Widget _buildViewAssignmentContent(BuildContext context, Map<String, dynamic> assignment) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20.0),
          margin: const EdgeInsets.only(top: 45.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10.0, offset: Offset(0.0, 10.0)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // To make the card compact
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment['title'] ?? 'No Title',
                  style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Status: ${assignment['s_name'] ?? 'Unknown'}',
                  style: TextStyle(
                    color: _getStatusColor(assignment['s_name'] ?? 'Unknown'),
                    fontSize: 18.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Start Date: ${assignment['created_at'] != null ? assignment['created_at'].substring(0, 10) : 'N/A'}',
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(height: 10),
                Text(
                  'Due Date: ${assignment['updated_at'] != null ? assignment['updated_at'].substring(0, 10) : 'N/A'}',
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                ),
                const SizedBox(height: 10),
                Text(
                  assignment['description'] ?? 'No Description',
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(height: 24.0),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 20.0,
          right: 20.0,
          child: CircleAvatar(
            backgroundColor: Colors.deepPurple,
            radius: 45.0,
            child: Icon(Icons.assignment, size: 50.0, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentTaskCard(Map<String, dynamic> assignment) {
    final startDate = assignment['created_at'] != null
        ? DateTime.parse(assignment['created_at'])
        : DateTime.now();
    final dueDate = assignment['updated_at'] != null
        ? DateTime.parse(assignment['updated_at'])
        : DateTime.now();
    final daysRemaining = dueDate.difference(DateTime.now()).inDays;

    return GestureDetector(
      onTap: () => _showViewAssignmentModal(assignment),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(4, 4),
            ),
          ],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: ListTile(
          title: Text(
            assignment['title'] ?? 'No Title',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${assignment['s_name'] ?? 'Unknown'}',
                style: TextStyle(color: _getStatusColor(assignment['s_name'] ?? 'Unknown')),
              ),
              Text(
                'Start Date: ${assignment['created_at'] != null ? assignment['created_at'].substring(0, 10) : 'N/A'}',
              ),
              Text(
                'Due Date: ${assignment['updated_at'] != null ? assignment['updated_at'].substring(0, 10) : 'N/A'}',
              ),
              Text('Days Remaining: $daysRemaining'),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Edit') {
                _showEditAssignmentModal(assignment);
              } else if (value == 'Delete') {
                _showDeleteConfirmation(assignment['as_id']);
              }
            },
            itemBuilder: (BuildContext context) {
              return ['Edit', 'Delete'].map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
            icon: const Icon(Icons.more_vert),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    List<Map<String, dynamic>> filteredAssignments = _assignments.where((assignment) {
      final matchesStatus = _selectedStatus == 'All Status' || assignment['s_name'] == _selectedStatus;
      final matchesProject = assignment['proj_id'] == widget.projectId;
      return matchesStatus && matchesProject;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: isDarkMode
                        ? const LinearGradient(
                      colors: [Color(0xFF424242), Color(0xFF303030)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(1, 1),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                      icon: const Icon(Icons.arrow_downward, color: Colors.amber),
                      iconSize: 28,
                      elevation: 16,
                      dropdownColor: isDarkMode ? const Color(0xFF424242) : Colors.white,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue!;
                        });
                      },
                      items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: _getStatusColor(value), size: 14),
                              const SizedBox(width: 10),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.greenAccent, Colors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10.0),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
                onPressed: _navigateToAddAssignment,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
              ? const Center(child: Text('Failed to load assignments'))
              : filteredAssignments.isEmpty
              ? const Center(child: Text('No assignment data to display'))
              : RefreshIndicator(
            onRefresh: _fetchAssignmentData,
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: filteredAssignments.length,
              itemBuilder: (context, index) {
                return _buildAssignmentTaskCard(filteredAssignments[index]);
              },
            ),
          ),
        ),
      ],
    );
  }
}
