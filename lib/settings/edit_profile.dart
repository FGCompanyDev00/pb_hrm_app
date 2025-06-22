// edit_profile_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pb_hrsystem/core/utils/auth_utils.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  EditProfilePageState createState() => EditProfilePageState();
}

class EditProfilePageState extends State<EditProfilePage> {
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

  late String baseUrl;
  late String profileEndpoint;
  late String displayMeEndpoint;
  late String requestChangeEndpoint;

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';
    profileEndpoint = '$baseUrl/api/profile/';
    displayMeEndpoint = '$baseUrl/api/display/me';
    requestChangeEndpoint = '$baseUrl/api/profile/request-change';

    _loadProfile();
  }

  /// Checks internet connectivity
  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Loads user profile data from the API
  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    if (!await _isConnected()) {
      _showDialog('No Internet',
          'Please check your internet connection and try again.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      // Use centralized auth validation with redirect
      if (!await AuthUtils.validateTokenAndRedirect(token,
          customMessage:
              'Authentication token not found. Please log in again.')) {
        return;
      }

      // Fetch profile details
      final profileResponse = await http.get(
        Uri.parse(profileEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (profileResponse.statusCode == 200) {
        final Map<String, dynamic> userProfile =
            jsonDecode(profileResponse.body)['results'];
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
      } else if (profileResponse.statusCode == 401) {
        _showDialog(
            'Unauthorized', 'Your session has expired. Please log in again.');
      } else {
        _showDialog('Error', 'Failed to load profile');
      }

      // Fetch profile image
      await _fetchUserProfile(token!);
    } on http.ClientException catch (e) {
      _showDialog('Network Error',
          'Failed to connect to the server. Please try again.');
      if (kDebugMode) {
        print('ClientException: $e');
      }
    } on SocketException catch (e) {
      _showDialog('Network Error',
          'No internet connection. Please check your settings.');
      if (kDebugMode) {
        print('SocketException: $e');
      }
    } on TimeoutException catch (e) {
      _showDialog('Timeout', 'The request timed out. Please try again later.');
      if (kDebugMode) {
        print('TimeoutException: $e');
      }
    } catch (e) {
      _showDialog('Error', 'An unexpected error occurred.');
      if (kDebugMode) {
        print('Unknown error: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches user profile image from the API
  Future<void> _fetchUserProfile(String token) async {
    try {
      final imageResponse = await http.get(
        Uri.parse(displayMeEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (imageResponse.statusCode == 200) {
        final List<dynamic> results = jsonDecode(imageResponse.body)['results'];
        if (results.isNotEmpty) {
          setState(() {
            _profileImageUrl = results[0]['images'];
          });
        }
      } else if (imageResponse.statusCode == 401) {
        _showDialog(
            'Unauthorized', 'Your session has expired. Please log in again.');
      } else {
        _showDialog('Error',
            'Failed to fetch profile image. (${imageResponse.statusCode})');
      }
    } on http.ClientException catch (e) {
      _showDialog(
          'Network Error', 'Failed to connect to the server for image.');
      if (kDebugMode) {
        print('ClientException: $e');
      }
    } on SocketException catch (e) {
      _showDialog(
          'Network Error', 'No internet connection while fetching image.');
      if (kDebugMode) {
        print('SocketException: $e');
      }
    } on TimeoutException catch (e) {
      _showDialog(
          'Timeout', 'The image request timed out. Please try again later.');
      if (kDebugMode) {
        print('TimeoutException: $e');
      }
    } catch (e) {
      _showDialog(
          'Error', 'An unexpected error occurred while fetching image.');
      if (kDebugMode) {
        print('Unknown error: $e');
      }
    }
  }

  /// Allows user to pick and compress an image from the gallery
  Future<void> _getImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        final fileSize = await file.length();

        if (fileSize > 5 * 1024 * 1024) {
          // 5MB limit
          // Compress the image
          final compressedFile = await _compressImage(file);
          if (compressedFile != null) {
            final compressedSize = await compressedFile.length();
            if (compressedSize > 5 * 1024 * 1024) {
              _showDialog('File Size Error',
                  'The selected image is too large even after compression. Please select an image under 5MB.');
            } else {
              setState(() {
                _image = compressedFile as File?;
              });
            }
          } else {
            _showDialog('Compression Error',
                'Failed to compress the image. Please try another image.');
          }
        } else {
          setState(() {
            _image = file;
          });
        }
      } else {
        // User canceled the picker
        if (kDebugMode) {
          print('Image picker canceled by user.');
        }
      }
    } catch (e) {
      _showDialog('Error', 'An error occurred while selecting the image.');
      if (kDebugMode) {
        print('Image picking error: $e');
      }
    }
  }

  /// Compresses the given image file and returns the compressed file.
  /// Returns null if compression fails.
  Future<XFile?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.absolute.path}/temp_compressed.jpg';

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Adjust quality as needed
        minWidth: 800, // Adjust dimensions as needed
        minHeight: 800,
      );

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Image compression error: $e');
      }
      return null;
    }
  }

  /// Saves the updated profile to the API
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      // Form validation failed
      return;
    }

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

    if (!await _isConnected()) {
      _showDialog('No Internet',
          'Please check your internet connection and try again.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token == null) {
        _showDialog('Authentication Error',
            'Authentication token not found. Please log in again.');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(requestChangeEndpoint),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add fields if they have changed
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

      // Add image if selected
      if (_image != null) {
        request.files
            .add(await http.MultipartFile.fromPath('images', _image!.path));
      }

      if (request.fields.isEmpty && request.files.isEmpty) {
        _showDialog('Info', 'No changes to update.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        if (responseBody['statusCode'] == 201) {
          _showDialog('Success', 'Profile updated successfully.');
          await _loadProfile();
          setState(() {
            _image = null;
          });
        } else {
          _showDialog('Error',
              'Failed to update profile: ${responseBody['message'] ?? 'Unknown error.'}');
        }
      } else if (response.statusCode == 413) {
        _showDialog('File Size Error',
            'The uploaded image is too large. Please select an image under 5MB.');
      } else if (response.statusCode == 401) {
        _showDialog(
            'Unauthorized', 'Your session has expired. Please log in again.');
      } else {
        _showDialog(
            'Error', 'Failed to update profile. (${response.statusCode})');
      }
    } on http.ClientException catch (e) {
      _showDialog('Network Error',
          'Failed to connect to the server. Please try again.');
      if (kDebugMode) {
        print('ClientException: $e');
      }
    } on SocketException catch (e) {
      _showDialog('Network Error',
          'No internet connection. Please check your settings.');
      if (kDebugMode) {
        print('SocketException: $e');
      }
    } on TimeoutException catch (e) {
      _showDialog('Timeout', 'The request timed out. Please try again later.');
      if (kDebugMode) {
        print('TimeoutException: $e');
      }
    } catch (e) {
      _showDialog(
          'Error', 'An unexpected error occurred while saving profile.');
      if (kDebugMode) {
        print('Unknown error: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Displays a dialog with a given title and message
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(
                title == 'Success'
                    ? Icons.check_circle
                    : title == 'Error' ||
                            title == 'Network Error' ||
                            title == 'Authentication Error' ||
                            title == 'Timeout' ||
                            title == 'No Internet' ||
                            title == 'File Size Error' ||
                            title == 'Compression Error'
                        ? Icons.error
                        : Icons.info,
                color: title == 'Success'
                    ? Colors.green
                    : title == 'Error' ||
                            title == 'Network Error' ||
                            title == 'Authentication Error' ||
                            title == 'Timeout' ||
                            title == 'No Internet' ||
                            title == 'File Size Error' ||
                            title == 'Compression Error'
                        ? Colors.red
                        : Colors.blue,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: title == 'Success'
                    ? Colors.green
                    : title == 'Error' ||
                            title == 'Network Error' ||
                            title == 'Authentication Error' ||
                            title == 'Timeout' ||
                            title == 'No Internet' ||
                            title == 'File Size Error' ||
                            title == 'Compression Error'
                        ? Colors.red
                        : Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Builds a customized text field
  Widget buildTextField({
    required String label,
    required String? value,
    required Function(String?) onChanged,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
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
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final mediaQuery = MediaQuery.of(context);
    final double appBarHeight = mediaQuery.size.height * 0.16;

    return Scaffold(
        body: Stack(children: [
      Positioned.fill(
        child: Column(
          children: [
            // Customized AppBar
            Container(
              height: appBarHeight,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(isDarkMode
                      ? 'assets/darkbg.png'
                      : 'assets/background.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white // White icon for dark mode
                              : Colors.black, // Black icon for light mode
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 24,
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
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
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
                            // Profile Image
                            GestureDetector(
                              onTap: _getImage,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 45,
                                    backgroundImage: _image != null
                                        ? FileImage(_image!)
                                        : (_profileImageUrl != null &&
                                                _profileImageUrl!.isNotEmpty
                                            ? NetworkImage(_profileImageUrl!)
                                                as ImageProvider
                                            : const AssetImage(
                                                'assets/avatar_placeholder.png')),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFDBB342),
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
                            // Province Field
                            buildTextField(
                              label: 'Province',
                              value: _province,
                              onChanged: (val) => _province = val ?? '',
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please enter your province.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            // City Field
                            buildTextField(
                              label: 'City',
                              value: _city,
                              onChanged: (val) => _city = val ?? '',
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please enter your city.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            // Village Field
                            buildTextField(
                              label: 'Village',
                              value: _village,
                              onChanged: (val) => _village = val ?? '',
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please enter your village.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            // Phone Number Field
                            buildTextField(
                              label: 'Phone Number',
                              value: _phoneNumber,
                              onChanged: (val) => _phoneNumber = val ?? '',
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please enter your phone number.';
                                }
                                final phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
                                if (!phoneRegExp.hasMatch(val)) {
                                  return 'Please enter a valid phone number.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            // Update Profile Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(
                                        0xFFDBB342) // Keep same color for dark mode
                                    : const Color(
                                        0xFFE3B200), // A different color for light mode if needed
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
                              ),
                              child: Text(
                                'Update Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
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
    ]));
  }
}
