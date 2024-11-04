// lib/login_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/login/date.dart';
import 'package:pb_hrsystem/login/notification_permission_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:flutter/services.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_offline/flutter_offline.dart';

import '../home/home_calendar.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  bool _gradientAnimation = false;
  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'Laos', 'Chinese'];
  final LocalAuthentication auth = LocalAuthentication();
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _biometricEnabled = false;
  late Timer _timer;
  late AnimationController _animationController;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _checkLocale();
    _startGradientAnimation();
    _loadSavedCredentials();
    _loadBiometricSetting();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _timer.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
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

  Future<void> _checkLocale() async {
    String? defaultLanguage = sl<UserPreferences>().getDefaultLanguage();
    setState(() {
      _selectedLanguage = defaultLanguage ?? 'English';
    });
  }

  Future<void> _loadBiometricSetting() async {
    bool canCheckBiometrics = await auth.canCheckBiometrics;
    bool isDeviceSupported = await auth.isDeviceSupported();

    String? biometricEnabled = await _storage.read(key: 'biometricEnabled');
    setState(() {
      _biometricEnabled = (biometricEnabled == 'true') && canCheckBiometrics && isDeviceSupported;
    });
  }

  Future<void> _login() async {
    bool isOnline = await InternetConnectionChecker().hasConnection;
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showCustomDialog(context, AppLocalizations.of(context)!.loginFailed, AppLocalizations.of(context)!.emptyFieldsMessage);
      return;
    }

    if (isOnline) {
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

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseBody = jsonDecode(response.body);
          final String token = responseBody['token'];
          final String employeeId = responseBody['id']; // Get the employee id

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('employee_id', employeeId); // Save employee id as current user id
          sl<UserPreferences>().setToken(token);
          sl<UserPreferences>().setLoggedIn(true);

          if (_rememberMe) {
            await _saveCredentials(username, password, token);
          } else {
            await _clearCredentials();
          }

          if (_biometricEnabled) {
            await _storage.write(key: 'username', value: username);
            await _storage.write(key: 'password', value: password);
            await _storage.write(key: 'biometricEnabled', value: 'true');
          }

          Provider.of<UserProvider>(context, listen: false).login(token);

          bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;

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
          _showOfflineOptionModal('API Error', 'The API is currently unavailable.');
        }
      } catch (e) {
        _showOfflineOptionModal('API Error', 'There is an issue with the server.');
      }
    } else {
      _showOfflineOptionModal('No Internet', 'You are currently offline.');
    }
  }

  Future<void> _showOfflineOptionModal(String title, String message) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: Tween(begin: -0.05, end: 0.05).animate(_animationController),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Do you want to use offline mode?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _offlineLogin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Okay", style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _offlineLogin() async {
    final box = await Hive.openBox('loginBox');
    final storedUsername = box.get('username');
    final storedPassword = box.get('password');
    final token = box.get('token');

    if (storedUsername == _usernameController.text.trim() &&
        storedPassword == _passwordController.text.trim() &&
        token != null) {
      Provider.of<UserProvider>(context, listen: false).login(token);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      _showCustomDialog(
        context,
        AppLocalizations.of(context)!.loginFailed,
        AppLocalizations.of(context)!.incorrectCredentials,
      );
    }
  }

  Future<void> _authenticate({bool useBiometric = true}) async {
    if (!_biometricEnabled) {
      _showCustomDialog(context, AppLocalizations.of(context)!.biometricDisabled, AppLocalizations.of(context)!.enableBiometric);
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
        print('Biometric authentication error: $e');
      }
    }

    if (authenticated) {
      // Attempt to retrieve stored credentials
      String? username = await _storage.read(key: 'username');
      String? password = await _storage.read(key: 'password');

      if (username != null && password != null) {
        // Use locally stored credentials for login
        _usernameController.text = username;
        _passwordController.text = password;

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');

        // Proceed with direct login if token exists
        if (token != null) {
          Provider.of<UserProvider>(context, listen: false).login(token);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeCalendar()),
          );
        } else {
          _showCustomDialog(context, AppLocalizations.of(context)!.loginFailed, AppLocalizations.of(context)!.incorrectCredentials);
        }
      } else {
        _showCustomDialog(context, AppLocalizations.of(context)!.loginFailed, AppLocalizations.of(context)!.incorrectCredentials);
      }
    } else {
      _showCustomDialog(context, AppLocalizations.of(context)!.authenticationFailed, AppLocalizations.of(context)!.authenticateToContinue);
    }
  }

  Future<void> _saveCredentials(String username, String password, String token) async {
    final box = await Hive.openBox('loginBox');
    await box.put('username', username);
    await box.put('password', password);
    await box.put('token', token);
  }

  Future<void> _loadSavedCredentials() async {
    final box = await Hive.openBox('loginBox');
    setState(() {
      _usernameController.text = box.get('username', defaultValue: '') as String;
      _passwordController.text = box.get('password', defaultValue: '') as String;
      _rememberMe = box.containsKey('username') && box.containsKey('password');
    });
  }

  Future<void> _clearCredentials() async {
    final box = await Hive.openBox('loginBox');
    await box.delete('username');
    await box.delete('password');
    await box.delete('token');
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
                  backgroundColor: const Color(0xFFDAA520),
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

  @override
  Widget build(BuildContext context) {
    var languageNotifier = Provider.of<LanguageNotifier>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: OfflineBuilder(
        connectivityBuilder: (context, connectivity, child) {
          final bool connected = connectivity != ConnectivityResult.none;
          return Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (!connected)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.red,
                    padding: const EdgeInsets.all(8.0),
                    child: const Center(
                      child: Text(
                        'No Internet Connection',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.05,
                        vertical: screenHeight * 0.02,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: screenHeight * 0.045),
                          _buildLanguageDropdown(languageNotifier, isDarkMode, screenWidth),
                          SizedBox(height: screenHeight * 0.005),
                          _buildLogoAndText(screenWidth, screenHeight),
                          SizedBox(height: screenHeight * 0.06),
                          _buildTextFields(screenWidth),
                          SizedBox(height: screenHeight * 0.02),
                          _buildRememberMeCheckbox(screenWidth),
                          SizedBox(height: screenHeight * 0.02),
                          _buildLoginAndBiometricButton(screenWidth),
                          SizedBox(height: screenHeight * 0.01),
                          const Spacer(),
                        ],
                      ),
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
                    padding: EdgeInsets.all(screenWidth * 0.075),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.chooseLanguage,
                              // Localized Text
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
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
                                width: screenWidth * 0.07,
                                height: screenWidth * 0.065,
                              ),
                              title: Text(
                                language,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedLanguage = language;
                                });
                                languageNotifier.changeLanguage(language);
                                Navigator.pop(context);
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
                  width: screenWidth * 0.15,
                  height: screenWidth * 0.14,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black54 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/flags/${_selectedLanguage.toLowerCase()}.png',
                      width: screenWidth * 0.08,
                      height: screenWidth * 0.09,
                    ),
                  ),
                ),
                Positioned(
                  top: screenWidth * 0.09,
                  child: Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: screenWidth * 0.06,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenWidth * 0.017),
          Text(
            _selectedLanguage,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: screenWidth * 0.035,
            ),
          ),
          SizedBox(height: screenWidth * 0.017),
        ],
      ),
    );
  }

  Widget _buildLogoAndText(double screenWidth, double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the start (left)
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              width: screenWidth * 0.4,
              height: screenHeight * 0.15,
              fit: BoxFit.contain,
            ),
            SizedBox(width: screenWidth * 0.01),
            _buildCustomDateRow(screenWidth),
          ],
        ),
        SizedBox(height: screenHeight * 0.01),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.welcomeToPSBV, // Localized Title
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 15),
              // Subtitle 1 with indentation
              Padding(
                padding: EdgeInsets.only(left: screenWidth * 0.04),
                child: Text(
                  AppLocalizations.of(context)!.welcomeSubtitle1, // Localized Subtitle 1
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              // Subtitle 2 with further indentation
              Padding(
                padding: EdgeInsets.only(left: screenWidth * 0.08),
                child: Text(
                  AppLocalizations.of(context)!.welcomeSubtitle2, // Localized Subtitle 2
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDateRow(double screenWidth) {
    return GestureDetector(
      onTap: () {
        _selectDate(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenWidth * 0.02,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEE9C3), Color(0xFFFFF3D6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: Offset(screenWidth * 0.005, screenWidth * 0.005),
              blurRadius: screenWidth * 0.01,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today,
              color: Colors.black54,
              size: 20.0,
            ),
            SizedBox(width: screenWidth * 0.02),
            Consumer<DateProvider>(
              builder: (context, dateProvider, child) {
                return Text(
                  dateProvider.formattedSelectedDate,
                  style: const TextStyle(
                    fontSize: 16,
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

  Widget _buildTextFields(double screenWidth) {
    return Column(
      children: [
        SizedBox(
          width: screenWidth * 0.8,
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
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(height: screenWidth * 0.05),
        SizedBox(
          width: screenWidth * 0.8,
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
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMeCheckbox(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      child: Row(
        children: [
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
          Text(
            AppLocalizations.of(context)!.rememberMe,
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginAndBiometricButton(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _biometricEnabled
                ? () => _authenticate(useBiometric: true)
                : () {
              _showCustomDialog(context, AppLocalizations.of(context)!.biometricDisabled, AppLocalizations.of(context)!.enableBiometric);
            },
            child: Container(
              width: screenWidth * 0.35,
              height: screenWidth * 0.125,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                color: Colors.grey[300],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face, size: screenWidth * 0.09, color: Colors.orange),
                  SizedBox(width: screenWidth * 0.025),
                  Icon(Icons.fingerprint, size: screenWidth * 0.1, color: Colors.orange),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _login,
            child: Container(
              width: screenWidth * 0.35,
              height: screenWidth * 0.125,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                color: Colors.green,
              ),
              alignment: Alignment.center,
              child: Text(
                AppLocalizations.of(context)!.login,
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
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
