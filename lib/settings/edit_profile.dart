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
  String _initialProvince = '';
  String _initialCity = '';
  String _initialVillage = '';
  String _initialPhoneNumber = '';
  String _province = '';
  String _city = '';
  String _village = '';
  String _phoneNumber = '';
  File? _image;
  String? _profileImageUrl;
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

      if (token == null) {
        _showDialog('Error', 'Authentication token not found.');
        return;
      }

      final profileResponse = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (profileResponse.statusCode == 200) {
        final Map<String, dynamic> userProfile = jsonDecode(profileResponse.body)['results'];
        setState(() {
          _initialProvince = userProfile['employee_province'] ?? '';
          _province = _initialProvince;
          _initialCity = userProfile['employee_district'] ?? '';
          _city = _initialCity;
          _initialVillage = userProfile['employee_village'] ?? '';
          _village = _initialVillage;
          _initialPhoneNumber = userProfile['employee_tel'] ?? '';
          _phoneNumber = _initialPhoneNumber;
        });
      } else {
        _showDialog('Error', 'Failed to load profile.');
      }

      await _fetchUserProfile(token);
    } catch (e) {
      _showDialog('Error', 'An error occurred while fetching profile data.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserProfile(String token) async {
    try {
      final imageResponse = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (imageResponse.statusCode == 200) {
        final List<dynamic> results = jsonDecode(imageResponse.body)['results'];
        if (results.isNotEmpty) {
          setState(() {
            _profileImageUrl = results[0]['images'];
          });
        }
      } else {
        _showDialog('Error', 'Failed to fetch profile image');
      }
    } catch (e) {
      _showDialog('Error', 'An error occurred while fetching profile image.');
    }
  }

  Future<void> _getImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
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
    if (_province == _initialProvince &&
        _city == _initialCity &&
        _village == _initialVillage &&
        _phoneNumber == _initialPhoneNumber &&
        _image == null) {
      _showDialog('Info', 'No changes to update.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null) {
        _showDialog('Error', 'Authentication token not found.');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://demo-application-api.flexiflows.co/api/profile/request-change'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (_province != _initialProvince) {
        request.fields['employee_province'] = _province;
      }

      if (_city != _initialCity) {
        request.fields['employee_district'] = _city;
      }

      if (_village != _initialVillage) {
        request.fields['employee_village'] = _village;
      }

      if (_phoneNumber != _initialPhoneNumber) {
        request.fields['employee_tel'] = _phoneNumber;
      }

      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath('images', _image!.path));
      }

      if (request.fields.isEmpty && request.files.isEmpty) {
        _showDialog('Info', 'No changes to update.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await request.send();

      if (response.statusCode == 201) {
        final responseData = await http.Response.fromStream(response);
        final Map<String, dynamic> responseBody = jsonDecode(responseData.body);

        if (responseBody['statusCode'] == 201) {
          _showDialog('Success', 'Profile updated successfully.');
          await _loadProfile();
          setState(() {
            _image = null;
          });
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

  Widget buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
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
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double appBarHeight = mediaQuery.size.height * 0.15;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Container(
                  height: appBarHeight,
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
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
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
                                      : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                      ? NetworkImage(_profileImageUrl!) as ImageProvider
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
}
