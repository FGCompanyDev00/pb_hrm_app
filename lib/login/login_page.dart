import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/login/forgot_password_page.dart';
import 'package:pb_hrsystem/login/notification_permission_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _gradientAnimation = false;
  String _selectedLanguage = 'English'; // Default language
  final List<String> _languages = ['English', 'Laos', 'Chinese'];
  final LocalAuthentication auth = LocalAuthentication();
  bool _rememberMe = false;
  bool _isPasswordVisible = false; // State variable for password visibility
  bool _biometricEnabled = false; // Biometric setting
  late Timer _timer;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage(); // Secure storage instance

  @override
  void initState() {
    super.initState();
    _startGradientAnimation();
    _loadSavedCredentials();
    _loadBiometricSetting();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when disposing the widget
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startGradientAnimation() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _gradientAnimation = !_gradientAnimation;
        });
      }
    });
  }

  Future<void> _loadBiometricSetting() async {
    String? biometricEnabled = await _storage.read(key: 'biometricEnabled');
    setState(() {
      _biometricEnabled = biometricEnabled == 'true';
    });
  }

  Future<void> _login() async {
    final String username = _usernameController.text;
    final String password = _passwordController.text;

    final response = await http.post(
      Uri.parse('https://demo-application-api.flexiflows.co/api/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      final String token = responseBody['token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token); // Save token

      if (_rememberMe) {
        _saveCredentials();
      } else {
        _clearCredentials();
      }

      // Save the credentials securely if biometric is enabled
      if (_biometricEnabled) {
        await _storage.write(key: 'username', value: username);
        await _storage.write(key: 'password', value: password);
        await _storage.write(key: 'biometricEnabled', value: 'true');
      }

      // Check if it's the first login on this device
      bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;
      if (kDebugMode) {
        print('isFirstLogin: $isFirstLogin');
      } // Debug print to check the value

      if (isFirstLogin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NotificationPermissionPage()),
        );
        await prefs.setBool('isFirstLogin', false);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else {
      _showCustomDialog(
          context,
          AppLocalizations.of(context)!.loginFailed,
          '${AppLocalizations.of(context)!.loginFailedMessage} ${response
              .reasonPhrase}'
      );
    }
  }

  Future<void> _authenticate({bool useBiometric = true}) async {
    if (!_biometricEnabled) {
      _showCustomDialog(context, 'Biometric Disabled',
          'Please enable biometric authentication.');
      return;
    }

    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Authenticate to login',
        options: AuthenticationOptions(
          biometricOnly: useBiometric,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Authentication error: $e');
      }
    }

    if (authenticated) {
      String? username = await _storage.read(key: 'username');
      String? password = await _storage.read(key: 'password');
      if (username != null && password != null) {
        _usernameController.text = username;
        _passwordController.text = password;
        _login();
      }
    } else {
      _showCustomDialog(context, 'Authentication Failed', 'Please try again.');
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('username', _usernameController.text);
    prefs.setString('password', _passwordController.text);
    prefs.setBool('rememberMe', _rememberMe);
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameController.text = prefs.getString('username') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
      _rememberMe = prefs.getBool('rememberMe') ?? false;
    });
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('username');
    prefs.remove('password');
    prefs.remove('rememberMe');
  }

  void _showCustomDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info, color: Colors.red, size: 50),
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

  Widget _buildForgotPasswordButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
        );
      },
      child: Text(
        AppLocalizations.of(context)!.forgotPassword,
        style: const TextStyle(color: Colors.green),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var languageNotifier = Provider.of<LanguageNotifier>(context);
    var currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView( // Wrap content with SingleChildScrollView
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLanguageDropdown(languageNotifier, isDarkMode),
                      const SizedBox(height: 10),
                      _buildLogoAndText(context),
                      const SizedBox(height: 55),
                      _buildTextFields(context),
                      const SizedBox(height: 20),
                      _buildRememberMeCheckbox(context),
                      const SizedBox(height: 20),
                      _buildLoginAndBiometricButton(context),
                      const SizedBox(height: 10),
                      _buildForgotPasswordButton(context),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(LanguageNotifier languageNotifier,
      bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 250.0, top: 100.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30.0)),
                ),
                builder: (BuildContext context) {
                  return Container(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Choose Language",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: isDarkMode ? Colors.white : Colors
                                      .black),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: _languages.length,
                          itemBuilder: (BuildContext context, int index) {
                            String language = _languages[index];
                            return ListTile(
                              leading: Image.asset(
                                'assets/flags/${language.toLowerCase()}.png',
                                width: 28,
                                height: 26,
                              ),
                              title: Text(language),
                              onTap: () {
                                setState(() {
                                  _selectedLanguage = language;
                                });
                                languageNotifier.changeLanguage(language);
                                Navigator.pop(context); // Close the modal
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70,
                  height: 65,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black54 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/flags/${_selectedLanguage.toLowerCase()}.png',
                      width: 30,
                      height: 29,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  child: Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 23,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _selectedLanguage,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLogoAndText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/logo.png',
              width: 160,
              height: 150,
            ),
            const SizedBox(width: 2),
            // Current Date
            _buildCustomDateRow(),
          ],
        ),
        const SizedBox(height: 10),
        // Welcome Text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 53.0),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to PSVB',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 15),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 65.0),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "You're not just another customer.\nWe're not just another Bank...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDateRow() {
  String currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Smaller padding
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFEE9C3), Color(0xFFFFF3D6)], 
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(15.0), 
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1), 
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.calendar_today,
          color: Colors.black54,
          size: 20.0, // Smaller icon size
        ),
        const SizedBox(width: 8), // Reduced spacing between the icon and text
        Text(
          currentDate,
          style: const TextStyle(
            fontSize: 16, // Smaller text size
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0, // Adjusted letter spacing
          ),
        ),
      ],
    ),
  );
}



  Widget _buildTextFields(BuildContext context) {
    return Column(
      children: [
        // Username TextField
        SizedBox(
          width: MediaQuery
              .of(context)
              .size
              .width * 0.8,
          child: TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.username,
              labelStyle: const TextStyle(color: Colors.black),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.black),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
                // Adjust for round corners
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Password TextField
        SizedBox(
          width: MediaQuery
              .of(context)
              .size
              .width * 0.8,
          child: TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.password,
              labelStyle: const TextStyle(color: Colors.black),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.black),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_outlined : Icons
                      .visibility_off_outlined,
                  color: Colors.black,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
                // Adjust for round corners
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMeCheckbox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),

      child: Row(
        children: [
          // Custom Checkbox
          Checkbox(
            value: _rememberMe,
            onChanged: (bool? value) {
              setState(() {
                _rememberMe = value!;
              });
            },
            activeColor: Colors.green,
            checkColor: Colors.white,
          ),
          // Remember Me Label
          Text(
            AppLocalizations.of(context)!.rememberMe,
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginAndBiometricButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 45.0),
      // Adjust the padding as needed
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // Evenly space the buttons
        children: [
          // Biometric Button
          GestureDetector(
            onTap: _biometricEnabled
                ? () => _authenticate(useBiometric: true)
                : () {
              _showCustomDialog(
                  context, AppLocalizations.of(context)!.biometricDisabled,
                  AppLocalizations.of(context)!.enableBiometric);
            },
            child: Container(
              width: MediaQuery
                  .of(context)
                  .size
                  .width * 0.35,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.grey[300],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face, size: 35, color: Colors.orange),
                  SizedBox(width: 10),
                  Icon(Icons.fingerprint, size: 38, color: Colors.orange),
                ],
              ),
            ),
          ),
          // Login Button
          GestureDetector(
            onTap: _login,
            child: Container(
              width: MediaQuery
                  .of(context)
                  .size
                  .width * 0.35,

              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.green,
              ),
              alignment: Alignment.center,
              child: Text(
                AppLocalizations.of(context)!.login,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
