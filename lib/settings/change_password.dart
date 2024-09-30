import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart'; // Added for decoding JWT tokens

import '../theme/theme.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String? _profileImageUrl; // Added to store profile image URL

  @override
  void initState() {
    super.initState();
    _fetchUserProfile(); // Fetch user profile on initialization
  }

  Future<void> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      // Handle the case when token is null
      return;
    }

    // Decode the JWT token to get the employee_id
    Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
    String? employeeId = decodedToken['employee_id']; // Adjust the key as per your token's payload

    if (employeeId == null) {
      // Handle the case when employee_id is not in the token
      return;
    }

    final response = await http.get(
      Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> profileData = jsonDecode(response.body)['results'];
      setState(() {
        _profileImageUrl = profileData['images'];
      });
    } else {
      // Handle error
      _showDialog(context, 'Error', 'Failed to fetch profile image');
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
        'oldpassword': _currentPasswordController.text,
        'newpassword': _newPasswordController.text,
        'passwordConfirm': _confirmPasswordController.text,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      _showDialog(context, 'Success', 'Password changed successfully');
    } else {
      Map<String, dynamic> responseData = jsonDecode(response.body);
      String errorMessage = responseData['message'] ?? 'Failed to change password';
      _showDialog(context, 'Error', errorMessage);
    }
  }

  void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: title == 'Error' ? Colors.red : Colors.green,
              ),
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

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // AppBar section with row for back button and title
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/yellow_bg.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 13.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Profile picture under the AppBar
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? NetworkImage(_profileImageUrl!)
                      : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 20),
                // Form fields
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Current password field
                            _buildPasswordField(
                              label: 'Current Password *',
                              controller: _currentPasswordController,
                              isPasswordVisible: _isCurrentPasswordVisible,
                              onToggleVisibility: () {
                                setState(() {
                                  _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            // New password field
                            _buildPasswordField(
                              label: 'New Password *',
                              controller: _newPasswordController,
                              isPasswordVisible: _isNewPasswordVisible,
                              onToggleVisibility: () {
                                setState(() {
                                  _isNewPasswordVisible = !_isNewPasswordVisible;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            // Confirm password field
                            _buildPasswordField(
                              label: 'Password (Confirm) *',
                              controller: _confirmPasswordController,
                              isPasswordVisible: _isConfirmPasswordVisible,
                              onToggleVisibility: () {
                                setState(() {
                                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                });
                              },
                            ),
                            const SizedBox(height: 30),
                            // Change password button
                            ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  if (_newPasswordController.text != _confirmPasswordController.text) {
                                    _showDialog(context, 'Error', 'Passwords do not match');
                                  } else {
                                    _changePassword();
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor: const Color(0xFFE3B200),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Cancel button
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  // Build password field
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isPasswordVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isPasswordVisible,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE3B200), // golden border color
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: Icon(
            isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: const Color(0xFF606060),
          ),
          onPressed: onToggleVisibility,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your ${label.replaceAll('*', '').trim()}';
        }
        return null;
      },
    );
  }
}
