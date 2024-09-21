import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late String _province = '';
  late String _city = '';
  late String _village = '';
  late String _phoneNumber = '';
  File? _image;
  String _imageUrl = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      // Fetch profile details
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userProfile = jsonDecode(response.body)['results'];

        setState(() {
          _province = userProfile['employee_province'] ?? '';
          _city = userProfile['employee_district'] ?? '';
          _village = userProfile['employee_village'] ?? '';
          _phoneNumber = userProfile['employee_tel'] ?? '';
        });

        // Fetch profile image
        _fetchProfileImage(userProfile['images']);
      } else {
        _showDialog('Error', 'Failed to load profile.');
      }
    } catch (e) {
      _showDialog('Error', 'An error occurred while fetching profile data.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProfileImage(String imagePath) async {
    setState(() {
      _imageUrl = 'https://demo-application-api.flexiflows.co/$imagePath';
    });
  }

  Future<void> _getImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);

      // Check if file size exceeds 5MB
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        _showDialog('Error', 'The selected image is too large. Please select an image under 5MB.');
      } else {
        setState(() {
          _image = file;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('token');

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://demo-application-api.flexiflows.co/api/profile/request-change'),
        );

        request.headers['Authorization'] = 'Bearer $token';
        request.fields['employee_province'] = _province;
        request.fields['employee_district'] = _city;
        request.fields['employee_village'] = _village;
        request.fields['employee_tel'] = _phoneNumber;

        if (_image != null) {
          request.files.add(await http.MultipartFile.fromPath('images', _image!.path));
        }

        final response = await request.send();

        if (response.statusCode == 200) {
          final responseData = await http.Response.fromStream(response);
          final Map<String, dynamic> responseBody = jsonDecode(responseData.body);

          if (responseBody['statusCode'] == 200) {
            _showDialog('Success', 'Profile updated successfully.');
          } else {
            _showDialog('Error', 'Failed to update profile: ${responseBody['message']}');
          }
        } else {
          _showDialog('Error', 'Failed to update profile.');
        }
      } catch (e) {
        _showDialog('Error', 'An error occurred while saving profile.');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                title == 'Success' ? Icons.check_circle : Icons.error,
                color: title == 'Success' ? Colors.green : Colors.red,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDAA520),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                // Top banner with back button and title
                Container(
                  height: mediaQuery.size.height * 0.15,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/background.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.black),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          const Spacer(),
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: mediaQuery.size.width * 0.05,
                      vertical: mediaQuery.size.height * 0.02,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _getImage,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage: _image != null
                                      ? FileImage(_image!)
                                      : (_imageUrl.isNotEmpty
                                      ? NetworkImage(_imageUrl) as ImageProvider
                                      : const AssetImage('assets/default_avatar.jpg')),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          buildTextField(
                            label: 'Province',
                            value: _province,
                            onChanged: (val) => _province = val,
                          ),
                          const SizedBox(height: 10),
                          buildTextField(
                            label: 'City',
                            value: _city,
                            onChanged: (val) => _city = val,
                          ),
                          const SizedBox(height: 10),
                          buildTextField(
                            label: 'Village',
                            value: _village,
                            onChanged: (val) => _village = val,
                          ),
                          const SizedBox(height: 10),
                          buildTextField(
                            label: 'Phone Number',
                            value: _phoneNumber,
                            onChanged: (val) => _phoneNumber = val,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDAA520),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            ),
                            child: const Text(
                              'Update Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
        ],
      ),
    );
  }

  Widget buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus && value.isNotEmpty) {
          setState(() {
            onChanged('');
          });
        }
      },
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Colors.grey.withOpacity(0.1),
        ),
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }
}
