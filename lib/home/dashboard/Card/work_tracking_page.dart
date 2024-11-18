// work_tracking_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/edit_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/view_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/project_management_page.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkTrackingPage extends StatefulWidget {
  final String? highlightedProjectId;

  const WorkTrackingPage({super.key, this.highlightedProjectId});
  static const String baseUrl = 'https://demo-application-api.flexiflows.co';

  @override
  _WorkTrackingPageState createState() => _WorkTrackingPageState();
}

class _WorkTrackingPageState extends State<WorkTrackingPage> {
  bool _isMyProjectsSelected = true;
  String _searchText = '';
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Finished'];
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = false;
  final WorkTrackingService _workTrackingService = WorkTrackingService();

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isMyProjectsSelected) {
        print('Fetching My Projects...');
        _projects = await _workTrackingService.fetchMyProjects();
        print('Fetched My Projects: $_projects');
      } else {
        print('Fetching All Projects...');
        final allProjects = await _workTrackingService.fetchAllProjects();
        final prefs = await SharedPreferences.getInstance();
        final currentUser = prefs.getString('user_id');
        print('Current User ID: $currentUser');

        _projects = allProjects.where((project) {
          return project['create_project_by'] != currentUser;
        }).toList();
        print('Filtered All Projects: $_projects');
      }
    } catch (e) {
      print('Error in _fetchProjects: $e');
      _showErrorDialog('Failed to fetch projects: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _refreshProjects() {
    print('Refreshing Projects...');
    _fetchProjects();
  }

  void _showErrorDialog(String message) {
    print('Showing Error Dialog: $message');
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

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return PopScope(
      onPopInvokedWithResult: (e, result) => Navigator.maybePop(context),
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: RefreshIndicator(
          onRefresh: _fetchProjects,
          child: Column(
            children: [
              _buildHeader(isDarkMode),
              const SizedBox(height: 10),
              _buildTabs(),
              const SizedBox(height: 8),
              _buildSearchBar(isDarkMode),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading ? _buildLoading() : _buildProjectsList(context, isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 60.0, left: 8.0, right: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
            Text(
              'Work Tracking',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Transform.translate(
              offset: const Offset(-12.0, 0.0),
              child: CircleAvatar(
                radius: 27,
                backgroundColor: Colors.green,
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 38),
                  onPressed: () {
                    print('Add Project button pressed.');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddProjectPage()),
                    ).then((value) {
                      if (value == true) {
                        print('Project added successfully. Refreshing projects...');
                        _refreshProjects();
                      }
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTabButton('My Project', _isMyProjectsSelected, () {
            setState(() {
              _isMyProjectsSelected = true;
              _fetchProjects();
            });
          }),
          _buildTabButton('All Project', !_isMyProjectsSelected, () {
            setState(() {
              _isMyProjectsSelected = false;
              _fetchProjects();
            });
          }),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Center(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.orange.shade800 : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (isSelected)
              Container(
                height: 2,
                width: double.infinity,
                color: Colors.orange.shade800,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Search Box
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search name',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  suffixIcon: Icon(Icons.search, color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.black),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Status Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                iconSize: 24,
                elevation: 16,
                style: const TextStyle(color: Colors.black),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedStatus = newValue!;
                  });
                },
                items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildProjectsList(BuildContext context, bool isDarkMode) {
    List<Map<String, dynamic>> filteredProjects = _projects.where((project) {
      bool statusMatch = _selectedStatus == 'All Status' || (project['s_name']?.toString().toLowerCase() == _selectedStatus.toLowerCase());
      bool searchMatch = project['p_name']?.toString().toLowerCase().contains(_searchText.toLowerCase()) ?? false;
      return statusMatch && searchMatch;
    }).toList();

    if (kDebugMode) {
      print('Filtered Projects Count: ${filteredProjects.length}');
    }

    if (filteredProjects.isEmpty) {
      return Center(
        child: Text(
          'Sorry, no projects match your search.',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(6.0),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        return _buildProjectCard(context, isDarkMode, filteredProjects[index], index);
      },
    );
  }

  Widget _buildProjectCard(BuildContext context, bool isDarkMode, Map<String, dynamic> project, int index) {
    final progressColors = {
      'Pending': const Color(0xFFDBB342),
      'Processing': Colors.blue,
      'Finished': Colors.green,
    };

    double progress = double.tryParse(project['precent']?.toString() ?? '0.0') ?? 0.0;
    Color statusColor = progressColors[project['s_name']] ?? Colors.grey;

    // Format the dates to only show the date part
    String formatDate(String? date) {
      if (date == null) return 'Unknown';
      try {
        return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
      } catch (e) {
        return date; // Fallback to the original date string if parsing fails
      }
    }

    return Slidable(
      key: ValueKey(index),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35,
        children: [
          CustomSlidableAction(
            onPressed: (context) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ViewProjectPage(project: project)),
              );
            },
            backgroundColor: Colors.blue,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, color: Colors.white, size: 24),
                SizedBox(height: 4),
                Text(
                  'View',
                  style: TextStyle(color: Colors.white, fontSize: 8),
                ),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (context) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProjectPage(
                    project: project,
                    onUpdate: (updatedProject) {
                      setState(() {
                        _projects[index] = updatedProject;
                      });
                      _refreshProjects();
                    },
                    onDelete: _refreshProjects,
                  ),
                ),
              );
            },
            backgroundColor: Colors.green,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit, color: Colors.white, size: 24),
                SizedBox(height: 4),
                Text(
                  'Edit',
                  style: TextStyle(color: Colors.white, fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectManagementPage(
                projectId: project['project_id'],
                baseUrl: WorkTrackingService.baseUrl,
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.4),
                blurRadius: 3.0,
                spreadRadius: 1.0,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: progress / 100),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) => LinearProgressIndicator(
                        value: value,
                        color: Color.lerp(Colors.red, statusColor, value),
                        backgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${project['precent'] ?? 0}%',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProjectPage(
                            project: project,
                            onUpdate: (updatedProject) {
                              setState(() {
                                _projects[index] = updatedProject;
                              });
                              _refreshProjects();
                            },
                            onDelete: _refreshProjects,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProjectPage(
                            project: project,
                            onUpdate: (updatedProject) {
                              setState(() {
                                _projects[index] = updatedProject;
                              });
                              _refreshProjects();
                            },
                            onDelete: _refreshProjects,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Update',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Title: ',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      project['p_name'] ?? 'No Title',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 14.0,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Deadline1: ',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0,
                        ),
                      ),
                      Text(
                        formatDate(project['dl']),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Deadline2: ',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0,
                        ),
                      ),
                      Text(
                        formatDate(project['extend']),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Status: ',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black38,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                    ),
                  ),
                  Text(
                    '${project['s_name'] ?? 'Unknown'}...',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Conditionally render created_by if in All Project section
              if (!_isMyProjectsSelected)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    project['create_project_by'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
