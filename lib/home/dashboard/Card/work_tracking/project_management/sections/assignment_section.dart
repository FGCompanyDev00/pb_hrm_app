import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_assignment.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:intl/intl.dart';

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

  // Defined statuses directly in the code
  final Map<String, String> _statusMap = {
    '87403916-9113-4e2e-9d7d-b5ed269fe20a': 'Error',
    '40d2ba5e-a978-47ce-bc48-caceca8668e9': 'Pending',
    '0a8d93f0-1c05-42b2-8e56-984a578ef077': 'Processing',
    'e35569eb-75e1-4005-9232-bfb57303b8b3': 'Finished',
  };

  // For status dropdown in edit modal
  final List<String> _statusNames = ['Pending', 'Processing', 'Finished', 'Error'];
  final Map<String, String> _statusNameToId = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

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
        _assignments = assignments.where((assignment) {
          return assignment['proj_id'] == widget.projectId;
        }).map((assignment) {
          // Ensure s_name is populated using status_id
          if (assignment['s_name'] == null || assignment['s_name'].isEmpty) {
            assignment['s_name'] = _statusMap[assignment['status_id']] ?? 'Unknown';
          }
          return assignment;
        }).toList();
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
      case 'Error':
        return Colors.red;
      default:
        return Colors.grey;
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
    String selectedStatusName = assignment['s_name'] ?? 'Pending'; // Use status name

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _buildEditAssignmentContent(
              context, titleController, descriptionController, selectedStatusName, assignment),
        );
      },
    );
  }

  Widget _buildEditAssignmentContent(
      BuildContext context,
      TextEditingController titleController,
      TextEditingController descriptionController,
      String selectedStatusName,
      Map<String, dynamic> assignment) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20.0),
          margin: const EdgeInsets.only(top: 45.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10.0, offset: Offset(0.0, 10.0)),
            ],
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    DropdownButtonFormField<String>(
                      value: selectedStatusName.isNotEmpty ? selectedStatusName : null,
                      decoration: const InputDecoration(labelText: 'Status'),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedStatusName = newValue!;
                        });
                      },
                      items: _statusNames.map((statusName) {
                        return DropdownMenuItem<String>(
                          value: statusName,
                          child: Text(statusName),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24.0),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Make an API call to update the assignment in the backend.
                          setState(() {
                            assignment['title'] = titleController.text;
                            assignment['description'] = descriptionController.text;
                            assignment['status_id'] = _statusNameToId[selectedStatusName] ?? '';
                            assignment['s_name'] = selectedStatusName;
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
              );
            },
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
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _buildViewAssignmentContent(context, assignment),
        );
      },
    );
  }

  Widget _buildViewAssignmentContent(BuildContext context, Map<String, dynamic> assignment) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd');

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
              mainAxisSize: MainAxisSize.min,
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
                  'Start Date: ${assignment['created_at'] != null ? dateFormat.format(DateTime.parse(assignment['created_at'])) : 'N/A'}',
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(height: 10),
                Text(
                  'Due Date: ${assignment['updated_at'] != null ? dateFormat.format(DateTime.parse(assignment['updated_at'])) : 'N/A'}',
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
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd');

    final startDate = assignment['created_at'] != null
        ? DateTime.parse(assignment['created_at'])
        : DateTime.now();
    final dueDate = assignment['updated_at'] != null
        ? DateTime.parse(assignment['updated_at'])
        : DateTime.now();
    final daysRemaining = dueDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () => _showViewAssignmentModal(assignment),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Menu
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assignment['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
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
                ],
              ),
              const SizedBox(height: 8.0),
              // Status Chip
              Chip(
                label: Text(
                  assignment['s_name'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: _getStatusColor(assignment['s_name'] ?? 'Unknown'),
              ),
              const SizedBox(height: 8.0),
              // Dates
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4.0),
                  Text(
                    'Start: ${assignment['created_at'] != null ? dateFormat.format(DateTime.parse(assignment['created_at'])) : 'N/A'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 16.0),
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4.0),
                  Text(
                    'Due: ${assignment['updated_at'] != null ? dateFormat.format(DateTime.parse(assignment['updated_at'])) : 'N/A'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              // Days Remaining
              Text(
                'Days Remaining: $daysRemaining',
                style: const TextStyle(fontSize: 14),
              ),
            ],
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
      final matchesStatus =
          _selectedStatus == 'All Status' || assignment['s_name'] == _selectedStatus;
      return matchesStatus;
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
                    color: isDarkMode ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      iconSize: 28,
                      elevation: 16,
                      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
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
                              Icon(Icons.circle,
                                  color: _getStatusColor(value), size: 14),
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
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.greenAccent, Colors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
