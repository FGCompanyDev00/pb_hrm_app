import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/edit_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/view_project.dart';
import 'package:pb_hrsystem/main.dart';
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
  final List<String> _statusOptions = ['All Status', 'Pending', 'In Progress', 'Completed'];
  final List<Map<String, dynamic>> _projects = [
    {
      'title': 'Human Resource Department',
      'deadline1': '26 Feb 2024',
      'deadline2': '26 Feb 2024',
      'status': 'Pending',
      'progress': 0.3,
      'author': 'John Doe',
    },
    {
      'title': 'Finance Department',
      'deadline1': '26 Mar 2024',
      'deadline2': '26 Mar 2024',
      'status': 'In Progress',
      'progress': 0.6,
      'author': 'Jane Doe',
    },
    {
      'title': 'IT Department',
      'deadline1': '26 Apr 2024',
      'deadline2': '26 Apr 2024',
      'status': 'Completed',
      'progress': 1.0,
      'author': 'Alice Smith',
    },
    {
      'title': 'HR Department',
      'deadline1': '24 Apr 2024',
      'deadline2': '29 Apr 2024',
      'status': 'In Progress',
      'progress': 0.5,
      'author': 'Mat Khan',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

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
              Container(
                height: 80,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
                    ),
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
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const AddProjectPage()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _buildTabButton('My Project', _isMyProjectsSelected, () {
                      setState(() {
                        _isMyProjectsSelected = true;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildTabButton('All Project', !_isMyProjectsSelected, () {
                      setState(() {
                        _isMyProjectsSelected = false;
                      });
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
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
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isMyProjectsSelected
                    ? _buildProjectsList(context, isDarkMode, showAuthor: false)
                    : _buildProjectsList(context, isDarkMode, showAuthor: true),
              ),
            ],
          ),
        ),
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

  Widget _buildProjectsList(BuildContext context, bool isDarkMode, {required bool showAuthor}) {
    List<Map<String, dynamic>> filteredProjects = _projects
        .where((project) =>
            (_selectedStatus == 'All Status' || project['status'] == _selectedStatus) &&
            (project['title'].toLowerCase().contains(_searchText.toLowerCase())))
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
        return _buildProjectCard(context, isDarkMode, filteredProjects[index], showAuthor: showAuthor);
      },
    );
  }

  Widget _buildProjectCard(BuildContext context, bool isDarkMode, Map<String, dynamic> project, {bool showAuthor = false}) {
    final progressColors = {
      'Pending': Colors.orange,
      'In Progress': Colors.blue,
      'Completed': Colors.green,
    };

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
                        child: EditProjectPage(project: project),
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
                      value: project['progress'],
                      color: progressColors[project['status']],
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(project['progress'] * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.update,
                    color: progressColors[project['status']],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Title: ${project['title']}',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dead-line1: ${project['deadline1']}    Dead-line2: ${project['deadline2']}',
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
                    project['status'],
                    style: TextStyle(
                      color: progressColors[project['status']],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (showAuthor)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          project['author'],
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}