import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late String _province = '';
  late String _district = '';
  late String _village = '';
  late String _tel = '';
  File? _image;
  String _imageUrl = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

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
        _province = userProfile['employee_province'];
        _district = userProfile['employee_district'];
        _village = userProfile['employee_village'];
        _tel = userProfile['employee_tel'];
        _imageUrl = userProfile['images'] ?? ''; // Load the profile image URL
      });
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  Future<void> _getImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://demo-application-api.flexiflows.co/api/profile/request-change'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['employee_province'] = _province;
      request.fields['employee_district'] = _district;
      request.fields['employee_village'] = _village;
      request.fields['employee_tel'] = _tel;

      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath('images', _image!.path));
      }

      final response = await request.send();
      setState(() {
        _isLoading = false;
      });

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
              Icon(title == 'Success' ? Icons.check_circle : Icons.error, color: title == 'Success' ? Colors.green : Colors.red, size: 50),
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
                  backgroundColor: const Color(0xFFDAA520), // gold color
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
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
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _province,
                    decoration: InputDecoration(
                      labelText: 'Province',
                      border: const OutlineInputBorder(),
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your province';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _province = value!;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _district,
                    decoration: InputDecoration(
                      labelText: 'City',
                      border: const OutlineInputBorder(),
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your city';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _district = value!;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _village,
                    decoration: InputDecoration(
                      labelText: 'Village',
                      border: const OutlineInputBorder(),
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your village';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _village = value!;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _tel,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: const OutlineInputBorder(),
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _tel = value!;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      '* Please Note\nAny changes to your information require approval and may take some time. Thank you for your patience!',
                      style: TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDAA520), // gold color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: const Center(
                      child: Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
