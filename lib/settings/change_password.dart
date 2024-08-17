import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/home/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  late Future<UserProfile> futureUserProfile;
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    futureUserProfile = fetchUserProfile();
  }

  Future<UserProfile> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> results = jsonDecode(response.body)['results'][0];
      final userProfile = UserProfile.fromJson(results);
      return userProfile;
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  Future<void> _changePassword() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('https://demo-application-api.flexiflows.co/api/changepassword'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': _currentPasswordController.text,
        'newPassword': _newPasswordController.text,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      _showSuccessDialog(context, 'Password changed successfully');
    } else {
      _showErrorDialog(context, 'Failed to change password: ${response.reasonPhrase}');
    }
  }

  void _showConfirmationDialog(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirm Change Password',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          content: Text(
            'Are you sure you want to change your password?',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changePassword();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
              child: Text(
                'Sure',
                style: TextStyle(color: isDarkMode ? Colors.black : Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: FutureBuilder<UserProfile>(
                        future: futureUserProfile,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          } else if (snapshot.hasData) {
                            return _buildContent(context, isDarkMode, snapshot.data!);
                          } else {
                            return const Center(child: Text('No data available'));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDarkMode, UserProfile userProfile) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(userProfile.imgUrl),
            backgroundColor: Colors.transparent,
          ),
          const SizedBox(height: 16),
          Text(
            '${userProfile.name} ${userProfile.surname}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 32),
          _buildPasswordField(
            context,
            'Current Password *',
            _currentPasswordController,
            isDarkMode,
            _isCurrentPasswordVisible,
                () {
              setState(() {
                _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            context,
            'New Password *',
            _newPasswordController,
            isDarkMode,
            _isNewPasswordVisible,
                () {
              setState(() {
                _isNewPasswordVisible = !_isNewPasswordVisible;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            context,
            'Confirm Password *',
            _confirmPasswordController,
            isDarkMode,
            _isConfirmPasswordVisible,
                () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                if (_newPasswordController.text != _confirmPasswordController.text) {
                  _showErrorDialog(context, 'Passwords do not match');
                } else {
                  _showConfirmationDialog(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
              'Change Password',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
      BuildContext context,
      String label,
      TextEditingController controller,
      bool isDarkMode,
      bool isPasswordVisible,
      VoidCallback toggleVisibility,
      ) {
    return TextFormField(
      controller: controller,
      obscureText: !isPasswordVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        filled: true,
        fillColor: isDarkMode ? Colors.black45 : Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: toggleVisibility,
        ),
      ),
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
    );
  }
}

class UserProfile {
  final String employeeId;
  final String name;
  final String surname;
  final String branchId;
  final String branchName;
  final String departmentId;
  final String departmentName;
  final String tel;
  final String email;
  final String employeeStatus;
  final String gender;
  final String createAt;
  final String updateAt;
  final String imgUrl;

  UserProfile({
    required this.employeeId,
    required this.name,
    required this.surname,
    required this.branchId,
    required this.branchName,
    required this.departmentId,
    required this.departmentName,
    required this.tel,
    required this.email,
    required this.employeeStatus,
    required this.gender,
    required this.createAt,
    required this.updateAt,
    required this.imgUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      employeeId: json['id'] ?? '',
      name: json['employee_name'] ?? '',
      surname: json['employee_surname'] ?? '',
      branchId: '',
      branchName: '',
      departmentId: '',
      departmentName: '',
      tel: '',
      email: json['employee_email'] ?? '',
      employeeStatus: '',
      gender: '',
      createAt: '',
      updateAt: '',
      imgUrl: json['images'] ?? 'default_avatar.jpg',
    );
  }
}
