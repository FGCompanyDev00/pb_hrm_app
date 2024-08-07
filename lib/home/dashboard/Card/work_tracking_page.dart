import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/edit_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/view_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/project_management_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class WorkTrackingPage extends StatefulWidget {
  const WorkTrackingPage({super.key});

  @override
  _WorkTrackingPageState createState() => _WorkTrackingPageState();
}

class _WorkTrackingPageState extends State<WorkTrackingPage> {
  bool _isMyProjectsSelected = true;
  String _searchText = '';
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Completed'];
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  void _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isMyProjectsSelected) {
        _projects = await WorkTrackingService().fetchMyProjects();
      } else {
        _projects = await WorkTrackingService().fetchAllProjects();
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addProject(Map<String, dynamic> project) {
    setState(() {
      _projects.add(project);
    });
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

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    // Get the auth token from wherever it is stored, e.g., from a Provider or a global variable.
    final String authToken = 'your-auth-token-here';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDarkMode, authToken),
              const SizedBox(height: 10),
              _buildTabs(),
              const SizedBox(height: 8),
              _buildSearchBar(isDarkMode),
              const SizedBox(height: 8),
              Expanded(child: _isLoading ? _buildLoading() : _buildProjectsList(context, isDarkMode)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode, String authToken) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              },
            ),
            Text(
              'Work Tracking',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.green,
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 30),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddProjectPage(onAddProject: (project) {})),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _buildTabButton('My Project', _isMyProjectsSelected, () {
            setState(() {
              _isMyProjectsSelected = true;
              _fetchProjects();
            });
          }),
          const SizedBox(width: 8),
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
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            color: isSelected ? (isDarkMode ? Colors.amber : Colors.orange) : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
            border: isSelected ? null : Border.all(color: isDarkMode ? Colors.white : Colors.black),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? (isDarkMode ? Colors.black : Colors.white) : (isDarkMode ? Colors.white : Colors.black),
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
                hintText: 'Search name',
                hintStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.white : Colors.black),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedStatus,
            icon: Icon(Icons.arrow_downward, color: isDarkMode ? Colors.white : Colors.black),
            iconSize: 24,
            elevation: 16,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            underline: Container(
              height: 2,
              color: Colors.transparent,
            ),
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
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildProjectsList(BuildContext context, bool isDarkMode) {
    List<Map<String, dynamic>> filteredProjects = _projects
        .where((project) =>
    (_selectedStatus == 'All Status' || project['s_name'] == _selectedStatus) &&
        (project['p_name']?.toLowerCase()?.contains(_searchText.toLowerCase()) ?? false))
        .toList();

    if (filteredProjects.isEmpty) {
      return Center(
        child: Text(
          'Sorry, no projects match your search.',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        return _buildProjectCard(context, isDarkMode, filteredProjects[index], index);
      },
    );
  }

  Widget _buildProjectCard(BuildContext context, bool isDarkMode, Map<String, dynamic> project, int index) {
    final progressColors = {
      'Pending': Colors.orange,
      'Processing': Colors.blue,
      'Completed': Colors.green,
    };

    double progress = double.tryParse(project['precent']?.toString() ?? '0.0') ?? 0.0;
    return Slidable(
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (BuildContext context) {
                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ViewProjectPage(project: project),
                      ),
                    ),
                  );
                },
              );
            },
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.visibility,
            label: 'View',
          ),
          SlidableAction(
            onPressed: (context) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (BuildContext context) {
                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: EditProjectPage(
                          project: project,
                          onUpdate: (updatedProject) {
                            setState(() {
                              _projects[index] = updatedProject;
                            });
                          },
                          onDelete: () {
                            setState(() {
                              _projects.removeAt(index);
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
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
              ),
            ),
          );
        },
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
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
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Project ID: ${project['project_id']}', // Correct field name for project ID
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Status: ',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      project['s_name'] ?? 'Unknown',
                      style: TextStyle(
                        color: progressColors[project['s_name']] ?? Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
