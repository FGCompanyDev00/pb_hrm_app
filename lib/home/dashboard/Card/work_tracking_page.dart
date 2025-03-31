// work_tracking_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/edit_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/view_project.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/project_management_page.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkTrackingPage extends StatefulWidget {
  final String? highlightedProjectId;

  const WorkTrackingPage({super.key, this.highlightedProjectId});

  @override
  WorkTrackingPageState createState() => WorkTrackingPageState();
}

class WorkTrackingPageState extends State<WorkTrackingPage>
    with SingleTickerProviderStateMixin {
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

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fetchProjects();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });

    // Ensure loading animation shows for at least 2 seconds
    final loadingTimer = Future.delayed(const Duration(seconds: 2));

    try {
      List<Map<String, dynamic>> fetchedProjects = [];

      if (_isMyProjectsSelected) {
        debugPrint('Fetching My Projects...');
        fetchedProjects = await _workTrackingService.fetchMyProjects();
        debugPrint('Fetched My Projects: $fetchedProjects');
      } else {
        debugPrint('Fetching All Projects...');
        final allProjects = await _workTrackingService.fetchAllProjects();
        final prefs = await SharedPreferences.getInstance();
        final currentUser = prefs.getString('user_id');
        debugPrint('Current User ID: $currentUser');

        fetchedProjects = allProjects.where((project) {
          return project['create_project_by'] != currentUser;
        }).toList();
        debugPrint('Filtered All Projects: $fetchedProjects');
      }

      // Sort the fetched projects based on 'update_project_at' in descending order
      fetchedProjects.sort((a, b) {
        DateTime aDate;
        DateTime bDate;

        try {
          aDate = DateTime.parse(a['created_project_at'] ?? '').toLocal();
        } catch (e) {
          aDate = DateTime.fromMillisecondsSinceEpoch(0);
        }

        try {
          bDate = DateTime.parse(b['created_project_at'] ?? '').toLocal();
        } catch (e) {
          bDate = DateTime.fromMillisecondsSinceEpoch(0);
        }

        return bDate.compareTo(aDate);
      });

      // Wait for both the loading timer and data fetch
      await loadingTimer;

      if (mounted) {
        setState(() {
          _projects = fetchedProjects;
          _isLoading = false;
        });
        _fadeController.forward(); // Start fade animation after data is loaded
      }
    } catch (e) {
      debugPrint('Error in _fetchProjects: $e');
      await loadingTimer; // Still wait for minimum loading time
      if (mounted) {
        _showErrorDialog('Failed to fetch projects: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _refreshProjects() {
    debugPrint('Refreshing Projects...');
    _fetchProjects();
  }

  void _showErrorDialog(String message) {
    debugPrint('Showing Error Dialog: $message');
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
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
        return;
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
      height: 140,
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
        padding: const EdgeInsets.only(top: 55.0, left: 16.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back Button
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            // Title
            Expanded(
              child: Text(
                'Work Tracking',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Add Project Button
            CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFDBB342) // Dark mode color
                  : Colors.green, // Light mode color
              child: Transform.scale(
                scale: 1.5,
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 24),
                  onPressed: () {
                    debugPrint('Add Project button pressed.');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddProjectPage()),
                    ).then((value) {
                      if (value == true) {
                        debugPrint(
                            'Project added successfully. Refreshing projects...');
                        _refreshProjects();
                      }
                    });
                  },
                  tooltip: 'Add Project',
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
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
                  color: isSelected ? const Color(0xFFDBB342) : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (isSelected)
              Container(
                height: 2,
                width: double.infinity,
                color: const Color(0xFFDBB342),
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
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade600
                        : Colors.grey.shade300),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search name',
                  hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 16.0),
                  suffixIcon: Icon(Icons.search,
                      color: isDarkMode
                          ? Colors.white
                          : Colors.grey), // Icon color change
                ),
                style: TextStyle(
                    color: isDarkMode
                        ? Colors.white
                        : Colors.black), // Text color change based on dark mode
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
              color: isDarkMode
                  ? Colors.grey[800]
                  : Colors.white, // Background color change
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                  color:
                      isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
              value: _selectedStatus,
              icon: Icon(Icons.arrow_drop_down,
                  color: isDarkMode ? Colors.white : Colors.grey),
              iconSize: 24,
              elevation: 16,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedStatus = newValue!;
                });
              },
              items:
                  _statusOptions.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Row(
                    children: [
                      if (value != 'All Status') ...[
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: value == 'Processing'
                                ? Colors.blue
                                : value == 'Pending'
                                    ? Colors.orange
                                    : value == 'Finished'
                                        ? Colors.green
                                        : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(value),
                    ],
                  ),
                );
              }).toList(),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Project Icon Animation Container
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer rotating circle
                      TweenAnimationBuilder(
                        duration: const Duration(seconds: 2),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.rotate(
                            angle: value * 2 * 3.14159,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.green[700]!
                                  : Colors.green,
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            ),
                          ),
                        ),
                      ),
                      // Project Icon with Pulse Animation
                      TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 1500),
                        tween: Tween(begin: 0.8, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Icon(
                          Icons.work_outline,
                          size: 40,
                          color: isDarkMode
                              ? Colors.green[700]
                              : Colors.green[600],
                        ),
                      ),
                      // Animated dots
                      ...List.generate(
                        8,
                        (index) => Positioned(
                          top: 35 + 25 * sin(index * 3.14159 / 4),
                          left: 35 + 25 * cos(index * 3.14159 / 4),
                          child: TweenAnimationBuilder(
                            duration:
                                Duration(milliseconds: 1000 + index * 100),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.green[700]?.withOpacity(value)
                                        : Colors.green[600]?.withOpacity(value),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Loading Text with Shimmer Effect
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      isDarkMode ? Colors.grey[300]! : Colors.grey[800]!,
                      isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                      isDarkMode ? Colors.grey[300]! : Colors.grey[800]!,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    tileMode: TileMode.mirror,
                  ).createShader(bounds),
                  child: Text(
                    'Fetching Projects Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait a moment...',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                // Progress Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => TweenAnimationBuilder(
                      duration: Duration(milliseconds: 400 + (index * 200)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.green[700]
                                  : Colors.green[600],
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      debugPrint('Filtered Projects Count: ${filteredProjects.length}');
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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(6.0),
        itemCount: filteredProjects.length,
        itemBuilder: (context, index) {
          return _buildProjectCard(
              context, isDarkMode, filteredProjects[index], index);
        },
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, bool isDarkMode,
      Map<String, dynamic> project, int index) {
    final progressColors = {
      'Pending': const Color(0xFFDBB342),
      'Processing': Colors.blue,
      'Finished': Colors.green,
    };

    double progress =
        double.tryParse(project['precent']?.toString() ?? '0.0') ?? 0.0;
    Color statusColor = progressColors[project['s_name']] ?? Colors.grey;

    // Format the dates to only show the date part
    String formatDate(String? date) {
      if (date == null) return 'Unknown';
      try {
        // Parse the date string
        DateTime parsedDate = DateTime.parse(date);
        // Convert to local time
        DateTime localDate = parsedDate.toLocal();
        // Format the date
        return DateFormat('dd MMM yyyy').format(localDate);
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return date; // Fallback to original string if parsing fails
      }
    }

    return Slidable(
      key: ValueKey(index),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.40,
        children: [
          CustomSlidableAction(
            onPressed: (context) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ViewProjectPage(project: project)),
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
                    projectId: project['project_id'],
                    baseUrl: _workTrackingService.baseUrl,
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
                baseUrl: _workTrackingService.baseUrl,
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.grey[850]
                : Colors.white, // Dark mode background color
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
                      builder: (context, value, child) =>
                          LinearProgressIndicator(
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
                            projectId: project['project_id'],
                            baseUrl: _workTrackingService.baseUrl,
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
                      child: const Icon(Icons.notifications,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProjectPage(
                            projectId: project['project_id'],
                            baseUrl: _workTrackingService.baseUrl,
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
