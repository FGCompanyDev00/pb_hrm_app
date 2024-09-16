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
        _city = userProfile['employee_district'];
        _village = userProfile['employee_village'];
        _phoneNumber = userProfile['employee_tel'];
        _imageUrl = userProfile['images'] ?? '';
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
      request.fields['employee_district'] = _city;
      request.fields['employee_village'] = _village;
      request.fields['employee_tel'] = _phoneNumber;

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

                Container(
                  height: mediaQuery.size.height * 0.13,
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
                          const Spacer(), // balance the back button
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
                          // Profile picture section
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
                                    child: const Icon(Icons.edit, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          buildTextField('Province', _province, (value) {
                            _province = value;
                          }),
                          const SizedBox(height: 16),
                          buildTextField('City', _city, (value) {
                            _city = value;
                          }),
                          const SizedBox(height: 16),
                          buildTextField('Village', _village, (value) {
                            _village = value;
                          }),
                          const SizedBox(height: 16),
                          buildTextField('Phone Number', _phoneNumber, (value) {
                            _phoneNumber = value;
                          }),
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Text(
                              '* Please Note\nAny changes to your information require approval and may take some time. Thank you for your patience!',
                              style: TextStyle(fontSize: 12, color: Colors.black),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: _saveProfile,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 5,
                                backgroundColor: Colors.orangeAccent,
                                shadowColor: Colors.orange.withOpacity(0.5),
                              ),
                              child: const Text(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String label, String initialValue, Function(String) onSaved) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
      onSaved: (value) {
        onSaved(value!);
      },
    );
  }
}
