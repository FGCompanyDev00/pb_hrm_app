// work_tracking_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/edit_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/view_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/project_management_page.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkTrackingPage extends StatefulWidget {
  final String? highlightedProjectId;

  const WorkTrackingPage({Key? key, this.highlightedProjectId}) : super(key: key);
  static const String baseUrl = 'https://demo-application-api.flexiflows.co';

  @override
  _WorkTrackingPageState createState() => _WorkTrackingPageState();
}

class _WorkTrackingPageState extends State<WorkTrackingPage> {
  bool _isMyProjectsSelected = true;
  String _searchText = '';
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = [
    'All Status',
    'Pending',
    'Processing',
    'Finished'
  ];
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

    return WillPopScope(
      onWillPop: () async {
        print('Back button pressed. Navigating to Dashboard...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Dashboard()),
        );
        return false;
      },
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
                child: _isLoading
                    ? _buildLoading()
                    : _buildProjectsList(context, isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
              isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
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
              onPressed: () {
                print('Back button pressed in Header. Navigating to Dashboard...');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const Dashboard()),
                      (Route<dynamic> route) => false,
                );
              },
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
              offset: const Offset(-15.0, 0.0),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.green,
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 30),
                  onPressed: () {
                    print('Add Project button pressed.');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddProjectPage()),
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
        children: [
          _buildTabButton('My Projects', _isMyProjectsSelected, () {
            print('Tab "My Projects" selected.');
            setState(() {
              _isMyProjectsSelected = true;
              _fetchProjects();
            });
          }),
          const SizedBox(width: 12),
          _buildTabButton('All Projects', !_isMyProjectsSelected, () {
            print('Tab "All Projects" selected.');
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
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode ? Colors.amber : Colors.orange)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
            border: isSelected
                ? null
                : Border.all(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? (isDarkMode ? Colors.black : Colors.white)
                    : (isDarkMode ? Colors.white : Colors.black),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search project name',
                hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search,
                    color: isDarkMode ? Colors.white : Colors.black),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              onChanged: (value) {
                print('Search text changed: $value');
                setState(() {
                  _searchText = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedStatus,
            icon: Icon(Icons.arrow_downward,
                color: isDarkMode ? Colors.white : Colors.black),
            iconSize: 24,
            elevation: 16,
            style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black),
            underline: Container(
              height: 2,
              color: Colors.transparent,
            ),
            onChanged: (String? newValue) {
              print('Status filter changed to: $newValue');
              setState(() {
                _selectedStatus = newValue!;
              });
            },
            items: _statusOptions
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
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
      bool statusMatch = _selectedStatus == 'All Status' ||
          (project['s_name']?.toString().toLowerCase() ==
              _selectedStatus.toLowerCase());
      bool searchMatch = project['p_name']
          ?.toString()
          .toLowerCase()
          .contains(_searchText.toLowerCase()) ??
          false;
      return statusMatch && searchMatch;
    }).toList();

    if (kDebugMode) {
      print('Filtered Projects Count: ${filteredProjects.length}');
    }

    if (filteredProjects.isEmpty) {
      return Center(
        child: Text(
          'Sorry, no projects match your search.',
          style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        return _buildProjectCard(
            context, isDarkMode, filteredProjects[index], index);
      },
    );
  }

  Widget _buildProjectCard(BuildContext context, bool isDarkMode,
      Map<String, dynamic> project, int index) {
    final progressColors = {
      'Pending': Colors.orange,
      'Processing': Colors.blue,
      'Finished': Colors.green,
    };

    double progress =
        double.tryParse(project['precent']?.toString() ?? '0.0') ?? 0.0;

    return Slidable(
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // View button
              GestureDetector(
                onTap: () {
                  print('View button tapped for Project ID: ${project['project_id']}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ViewProjectPage(project: project),
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.blue,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/layer.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'View',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Edit button
              GestureDetector(
                onTap: () {
                  print('Edit button tapped for Project ID: ${project['project_id']}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProjectPage(
                        project: project,
                        onUpdate: (updatedProject) {
                          setState(() {
                            _projects[index] = updatedProject;
                          });
                          print('Project updated: $updatedProject');
                          _refreshProjects(); // Auto-refresh after update
                        },
                        onDelete: () {
                          print('Project deleted: ${project['project_id']}');
                          _refreshProjects(); // Auto-refresh after deletion
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.green,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/element-plus.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Edit',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          print('Navigating to ProjectManagementPage with projectId: ${project['project_id']}');
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
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 12.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        color: progressColors[project['s_name']],
                        backgroundColor: Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${project['precent']}%',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.update,
                      color: progressColors[project['s_name']],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Title: ${project['p_name']}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Project ID: ${project['project_id']}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Deadline: ${project['dl']}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  'Extended Deadline: ${project['extend']}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Status: ',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 16.0,
                      ),
                    ),
                    Text(
                      project['s_name'] ?? 'Unknown',
                      style: TextStyle(
                        color: progressColors[project['s_name']] ?? Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                  ],
                ),
                if (!_isMyProjectsSelected)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: RichText(
                        text: TextSpan(
                          text: 'Created by: ',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: project['create_project_by'],
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
