// login_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/login/date.dart';
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
    if (mounted) {
      setState(() {
        _biometricEnabled = biometricEnabled == 'true';
      });
    }
  }

  Future<void> _login() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    // Basic input validation
    if (username.isEmpty || password.isEmpty) {
      _showCustomDialog(
        context,
        AppLocalizations.of(context)!.loginFailed,
        AppLocalizations.of(context)!.emptyCredentialsMessage,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final String token = responseBody['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token); // Save token

        if (_rememberMe) {
          await _saveCredentials();
        } else {
          await _clearCredentials();
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
          '${AppLocalizations.of(context)!.loginFailedMessage} ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      if (!mounted) return;
      _showCustomDialog(
        context,
        AppLocalizations.of(context)!.loginFailed,
        AppLocalizations.of(context)!.networkErrorMessage,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authenticate({bool useBiometric = true}) async {
    if (!_biometricEnabled) {
      _showCustomDialog(
        context,
        AppLocalizations.of(context)!.biometricDisabled,
        AppLocalizations.of(context)!.enableBiometric,
      );
      return;
    }

    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: AppLocalizations.of(context)!.authenticateToLogin,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Authentication error: $e');
      }
    }

    if (!mounted) return;

    if (authenticated) {
      String? username = await _storage.read(key: 'username');
      String? password = await _storage.read(key: 'password');
      if (username != null && password != null) {
        setState(() {
          _usernameController.text = username;
          _passwordController.text = password;
        });
        _login();
      }
    } else {
      _showCustomDialog(
        context,
        AppLocalizations.of(context)!.authenticationFailed,
        AppLocalizations.of(context)!.pleaseTryAgain,
      );
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text.trim());
    await prefs.setString('password', _passwordController.text.trim());
    await prefs.setBool('rememberMe', _rememberMe);
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _usernameController.text = prefs.getString('username') ?? '';
        _passwordController.text = prefs.getString('password') ?? '';
        _rememberMe = prefs.getBool('rememberMe') ?? false;
      });
    }
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    await prefs.remove('rememberMe');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: Provider.of<DateProvider>(context, listen: false).selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      Provider.of<DateProvider>(context, listen: false).updateSelectedDate(pickedDate);
    }
  }

  void _showCustomDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info, color: Colors.red, size: 50),
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDAA520), // Gold color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to calculate responsive font size
  double getResponsiveFontSize(double baseSize, double screenWidth) {
    // Adjust the divisor to control responsiveness
    return baseSize * (screenWidth / 375); // 375 is a base width (e.g., iPhone 8)
  }

  // Loading state for login
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    var languageNotifier = Provider.of<LanguageNotifier>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    // Obtain screen size
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    // Determine orientation
    final bool isPortrait = screenHeight > screenWidth;

    // Calculate responsive sizes
    final double logoSize = isPortrait
        ? screenWidth * 0.3 // 30% of screen width in portrait
        : screenHeight * 0.3; // 30% of screen height in landscape

    // Responsive font sizes
    final double titleFontSize = getResponsiveFontSize(22, screenWidth);
    final double subtitleFontSize = getResponsiveFontSize(16, screenWidth);
    final double buttonFontSize = getResponsiveFontSize(18, screenWidth);

    // Responsive padding
    final double horizontalPadding = screenWidth * 0.05; // 5% of screen width
    final double verticalPadding = screenHeight * 0.02; // 2% of screen height

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Container(
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
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - verticalPadding * 2,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLanguageDropdown(languageNotifier, isDarkMode, screenWidth),
                        SizedBox(height: screenHeight * 0.02),
                        _buildLogoAndText(
                          context,
                          logoSize,
                          titleFontSize,
                          subtitleFontSize,
                          isDarkMode,
                          screenWidth,
                        ),
                        SizedBox(height: screenHeight * 0.03),
                        _buildTextFields(context, screenWidth),
                        SizedBox(height: screenHeight * 0.02),
                        _buildRememberMeCheckbox(context, screenWidth),
                        SizedBox(height: screenHeight * 0.02),
                        _buildLoginAndBiometricButton(context, screenWidth, buttonFontSize),
                        SizedBox(height: screenHeight * 0.01),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : const SizedBox.shrink(),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(LanguageNotifier languageNotifier, bool isDarkMode, double screenWidth) {
    return Align(
      alignment: Alignment.topRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
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
                              AppLocalizations.of(context)!.chooseLanguage,
                              style: TextStyle(
                                fontSize: getResponsiveFontSize(18, screenWidth),
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
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
                              title: Text(
                                language,
                                style: TextStyle(
                                  fontSize: getResponsiveFontSize(16, screenWidth),
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
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
                  width: screenWidth * 0.15, // 15% of screen width
                  height: screenWidth * 0.15, // Maintain square aspect ratio
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black54 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/flags/${_selectedLanguage.toLowerCase()}.png',
                      width: screenWidth * 0.07, // 7% of screen width
                      height: screenWidth * 0.07,
                    ),
                  ),
                ),
                Positioned(
                  bottom: screenWidth * 0.005, // Adjust based on screen width
                  child: Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: screenWidth * 0.06, // 6% of screen width
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 7),
          Text(
            _selectedLanguage,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: getResponsiveFontSize(18, screenWidth),
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLogoAndText(
      BuildContext context,
      double logoSize,
      double titleFontSize,
      double subtitleFontSize,
      bool isDarkMode,
      double screenWidth,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo and Date Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/logo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
            SizedBox(width: screenWidth * 0.02),
            // Current Date
            _buildCustomDateRow(screenWidth),
          ],
        ),
        SizedBox(height: 10),
        // Welcome Text
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Text(
            AppLocalizations.of(context)!.welcomeToPSBV,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        // Subtitle Text
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
          child: Text(
            AppLocalizations.of(context)!.welcomeSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDateRow(double screenWidth) {
    return GestureDetector(
      onTap: () {
        _selectDate(context); // Trigger date picker when the row is tapped
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04, // 4% of screen width
          vertical: screenWidth * 0.02, // 2% of screen width
        ),
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
            Icon(
              Icons.calendar_today,
              color: Colors.black54,
              size: screenWidth * 0.05, // 5% of screen width
            ),
            SizedBox(width: screenWidth * 0.02),
            Consumer<DateProvider>(
              builder: (context, dateProvider, child) {
                return Text(
                  dateProvider.formattedSelectedDate, // Display formatted selected date
                  style: TextStyle(
                    fontSize: screenWidth * 0.04, // 4% of screen width
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFields(BuildContext context, double screenWidth) {
    // Responsive width for text fields
    final double textFieldWidth = screenWidth * 0.8; // 80% of screen width

    return Column(
      children: [
        // Username TextField
        SizedBox(
          width: textFieldWidth,
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
        SizedBox(height: screenWidth * 0.05), // 5% of screen width
        // Password TextField
        SizedBox(
          width: textFieldWidth,
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
                  _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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

  Widget _buildRememberMeCheckbox(BuildContext context, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Row(
        children: [
          // Custom Checkbox
          Checkbox(
            value: _rememberMe,
            onChanged: (bool? value) {
              setState(() {
                _rememberMe = value ?? false;
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

  Widget _buildLoginAndBiometricButton(
      BuildContext context,
      double screenWidth,
      double buttonFontSize,
      ) {
    // Responsive button width
    final double buttonWidth = screenWidth * 0.35; // 35% of screen width
    final double iconSize = screenWidth * 0.08; // 8% of screen width

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Biometric Button
          GestureDetector(
            onTap: _biometricEnabled
                ? () => _authenticate(useBiometric: true)
                : () {
              _showCustomDialog(
                context,
                AppLocalizations.of(context)!.biometricDisabled,
                AppLocalizations.of(context)!.enableBiometric,
              );
            },
            child: Container(
              width: buttonWidth,
              height: screenWidth * 0.12, // 12% of screen width
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.grey[300],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face, size: iconSize, color: Colors.orange),
                  SizedBox(width: screenWidth * 0.02),
                  Icon(Icons.fingerprint, size: iconSize, color: Colors.orange),
                ],
              ),
            ),
          ),
          // Login Button
          GestureDetector(
            onTap: _login,
            child: Container(
              width: buttonWidth,
              height: screenWidth * 0.12, // 12% of screen width
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.green,
              ),
              alignment: Alignment.center,
              child: Text(
                AppLocalizations.of(context)!.login,
                style: TextStyle(
                  fontSize: buttonFontSize,
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
