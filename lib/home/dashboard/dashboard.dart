// dashboard.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approvals_page/approvals_main_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/returnCar/car_return_page.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';
import 'package:pb_hrsystem/home/qr_profile_page.dart';
import 'package:pb_hrsystem/notifications/notification_page.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/settings_page.dart';
import 'package:pb_hrsystem/login/login_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _hasUnreadNotifications = true;
  late Future<UserProfile> futureUserProfile;
  late Future<List<String>> futureBanners;
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;
  bool _isLoading = false;
  bool get wantKeepAlive => true;

  // Hive boxes
  late Box<String> userProfileBox;
  late Box<List<String>> bannersBox;

  @override
  void initState() {
    super.initState();
    // Initialize Hive boxes
    _initializeHiveBoxes();

    // Fetch user data and banners
    Provider.of<UserProvider>(context, listen: false).fetchAndUpdateUser();
    futureUserProfile = fetchUserProfile();
    futureBanners = fetchBanners();

    // Initialize PageController
    _pageController = PageController(initialPage: _currentPage);

    // Start auto-swiping the carousel every 5 seconds
    _startCarouselTimer();
  }

  // Initialize Hive boxes
  Future<void> _initializeHiveBoxes() async {
    // Open 'userProfileBox' if not already open
    if (!Hive.isBoxOpen('userProfileBox')) {
      await Hive.openBox<String>('userProfileBox');
    }
    userProfileBox = Hive.box<String>('userProfileBox');

    // Open 'bannersBox' if not already open
    if (!Hive.isBoxOpen('bannersBox')) {
      await Hive.openBox<List<String>>('bannersBox');
    }
    bannersBox = Hive.box<List<String>>('bannersBox');
  }

  // Start the carousel auto-swipe timer
  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        // Calculate the total number of pages
        double maxScrollExtent = _pageController.position.maxScrollExtent;
        double viewportDimension = _pageController.position.viewportDimension;
        int totalPages = (maxScrollExtent / viewportDimension).ceil();

        if (nextPage >= totalPages) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
        setState(() {
          _currentPage = nextPage;
        });
      }
    });
  }

  // Fetch user profile from API or Hive
  Future<UserProfile> fetchUserProfile() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    try {
      // Fetch profile data online
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseJson = jsonDecode(response.body);
        final List<dynamic> results = responseJson['results'];
        if (results.isNotEmpty) {
          final Map<String, dynamic> userJson = results[0];
          final userProfile = UserProfile.fromJson(userJson);

          // Save the profile as a JSON string to Hive
          await userProfileBox.put('userProfile', jsonEncode(userProfile.toJson()));

          if (kDebugMode) {
            print("Fetched and saved user profile to Hive successfully.");
          }
          return userProfile;
        } else {
          if (kDebugMode) {
            print("Error: No data available in the response.");
          }
          throw Exception(AppLocalizations.of(context)!.noDataAvailable);
        }
      } else {
        if (kDebugMode) {
          print("Error: Failed to fetch data. Status Code: ${response.statusCode}");
        }
        // Removed the exception related to 'failedToLoadBanners'
        throw Exception(AppLocalizations.of(context)!.errorWithDetails('Status Code: ${response.statusCode}'));
      }
    } catch (e) {
      if (kDebugMode) {
        print("Network error: $e. Attempting to retrieve profile from Hive.");
      }

      // Retrieve profile from Hive if network request fails
      final cachedProfileJson = userProfileBox.get('userProfile');
      if (cachedProfileJson != null) {
        final userProfile = UserProfile.fromJson(jsonDecode(cachedProfileJson));
        if (kDebugMode) {
          print("Retrieved user profile from Hive successfully.");
        }
        return userProfile;
      } else {
        if (kDebugMode) {
          print("Error: No cached profile data available in Hive.");
        }
        throw Exception(AppLocalizations.of(context)!.noDataAvailable);
      }
    } finally {
      setState(() {
        _isLoading = false; // End loading
      });
    }
  }

  // Fetch banners from API or Hive
  Future<List<String>> fetchBanners() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/app/promotions/files/active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body)['results'];
        final banners = results.map<String>((file) => file['files'] as String).toList();

        // Save banners to Hive
        await bannersBox.put('banners', banners);

        return banners;
      } else {
        if (kDebugMode) {
          print("Error: Failed to load banners. Status Code: ${response.statusCode}");
        }
        // Instead of throwing an exception, return cached banners or an empty list
        return bannersBox.get('banners') ?? [];
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching banners: $e. Attempting to retrieve from Hive.");
      }

      // Retrieve from Hive if network request fails
      return bannersBox.get('banners') ?? [];
    }
  }

  // Refresh user profile manually
  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel(); // Cancel the carousel timer to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return PopScope(
      onPopInvokedWithResult: (e, result) => false, // Disable back button
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(140.0),
          child: FutureBuilder<UserProfile>(
            future: futureUserProfile,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildAppBarPlaceholder();
              } else if (snapshot.hasError) {
                return _buildErrorAppBar(snapshot.error.toString());
              } else if (snapshot.hasData) {
                final userProfile = snapshot.data!;
                return _buildAppBar(userProfile, isDarkMode);
              } else {
                return _buildErrorAppBar(AppLocalizations.of(context)!.noDataAvailable);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            if (isDarkMode) _buildDarkBackground(),
            // Make the body scrollable
            SingleChildScrollView(
              child: _buildMainContent(context, isDarkMode),
            ),
            if (_isLoading) _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  // AppBar Placeholder while loading
  PreferredSizeWidget _buildAppBarPlaceholder() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  // AppBar with error message
  PreferredSizeWidget _buildErrorAppBar(String errorMessage) {
    return AppBar(
      title: Text(
        AppLocalizations.of(context)!.errorWithDetails(errorMessage),
        style: const TextStyle(color: Colors.red),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  // AppBar with user information
  PreferredSizeWidget _buildAppBar(UserProfile userProfile, bool isDarkMode) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.black, size: 40),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsPage()),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: userProfile.imgName != 'default_avatar.jpg' ? NetworkImage(userProfile.imgName) : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                          backgroundColor: Colors.white,
                          onBackgroundImageError: (_, __) {
                            const AssetImage('assets/default_avatar.png');
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)!.greeting(userProfile.name),
                          style: const TextStyle(color: Colors.black, fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.power_settings_new, color: Colors.black, size: 40),
                    onPressed: () => _showLogoutDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dark mode background
  Widget _buildDarkBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/darkbg.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBannerCarousel(),
        const SizedBox(height: 10),
        _buildActionMenuHeader(),
        const SizedBox(height: 6),
        // Use Expanded here to allow scrolling of the GridView
        _buildActionGrid(isDarkMode),
      ],
    );
  }

  // Banner Carousel
  Widget _buildBannerCarousel() {
    return SizedBox(
      height: 175.0,
      child: FutureBuilder<List<String>>(
        future: futureBanners,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text(AppLocalizations.of(context)!.errorWithDetails(snapshot.error.toString())));
          } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
            return PageView.builder(
              controller: _pageController,
              itemCount: snapshot.data!.length,
              onPageChanged: (int index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final bannerUrl = snapshot.data![index];

                if (bannerUrl.isEmpty || Uri.tryParse(bannerUrl)?.hasAbsolutePath != true) {
                  return Center(child: Text(AppLocalizations.of(context)!.noBannersAvailable));
                }
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: NetworkImage(bannerUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            );
          } else {
            return Center(child: Text(AppLocalizations.of(context)!.noBannersAvailable));
          }
        },
      ),
    );
  }

  // Action Menu Header
  Widget _buildActionMenuHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              color: Colors.green,
              margin: const EdgeInsets.only(right: 12),
            ),
            Text(
              AppLocalizations.of(context)!.actionMenu,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            Text(
              AppLocalizations.of(context)!.notification,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            Stack(
              children: [
                IconButton(
                  icon: Image.asset(
                    'assets/notification-status.png',
                    width: 24,
                    height: 24,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationPage()),
                    ).then((_) {
                      setState(() {
                        _hasUnreadNotifications = false;
                      });
                    });
                  },
                ),
                if (_hasUnreadNotifications)
                  Positioned(
                    right: 11,
                    top: 11,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(bool isDarkMode) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // Determine the number of columns based on screen width
    int crossAxisCount = screenWidth < 600 ? 3 : 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.9,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
        ),
        itemCount: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          // List of action card data
          final List<Map<String, dynamic>> actionItems = [
            {
              'icon': 'assets/data-2.png',
              'label': AppLocalizations.of(context)!.history,
              'onTap': () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              ),
            },
            {
              'icon': 'assets/people.png',
              'label': AppLocalizations.of(context)!.approvals,
              'onTap': () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ApprovalsMainPage()),
              ),
            },
            {
              'icon': 'assets/status-up.png',
              'label': AppLocalizations.of(context)!.workTracking,
              'onTap': () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WorkTrackingPage()),
              ),
            },
            {
              'icon': 'assets/car_return.png',
              'label': AppLocalizations.of(context)!.carReturn,
              'onTap': () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReturnCarPage()),
              ),
            },
            {
              'icon': 'assets/KPI.png',
              'label': AppLocalizations.of(context)!.kpi,
              'onTap': () {}, // Add functionality if needed
            },
            {
              'icon': 'assets/inventory.png',
              'label': AppLocalizations.of(context)!.inventory,
              'onTap': () {}, // Add functionality if needed
            },
          ];

          // Build each action card using the data
          final item = actionItems[index];
          return Tooltip(
            message: item['label'],
            child: _buildActionCard(
              context,
              item['icon'],
              item['label'],
              isDarkMode,
              item['onTap'],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String imagePath, String title, bool isDarkMode, VoidCallback onTap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double iconSize = constraints.maxWidth * 0.4;
        double fontSize = constraints.maxWidth * 0.1;
        fontSize = fontSize.clamp(12.0, 16.0);

        return Card(
          color: isDarkMode ? Colors.black54 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFDBB342), width: 0.65),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.blue.withAlpha(50),
            splashFactory: InkRipple.splashFactory,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    imagePath,
                    height: iconSize,
                    width: iconSize,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/lock-circle.png',
                    height: 60,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)!.logoutTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C640C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.logoutConfirmation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F1E0),
                          foregroundColor: const Color(0xFFDBB342),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Provider.of<UserProvider>(context, listen: false).logout();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDBB342),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.yesLogout),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Loading Indicator Overlay
  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      ),
    );
  }
}

// UserProfile Model
class UserProfile {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String imgName;
  final List<String> roles;

  UserProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.imgName,
    required this.roles,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> rolesList = [];
    if (json['roles'] is List) {
      rolesList = List<String>.from(json['roles']);
    } else if (json['roles'] is String) {
      rolesList = (json['roles'] as String).split(',').map((role) => role.trim()).toList();
    }

    return UserProfile(
      id: json['id'].toString(),
      name: json['employee_name'],
      surname: json['employee_surname'],
      email: json['employee_email'],
      imgName: json['images'],
      roles: rolesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_name': name,
      'employee_surname': surname,
      'employee_email': email,
      'images': imgName,
      'roles': roles,
    };
  }
}
