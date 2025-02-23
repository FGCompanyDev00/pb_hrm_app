// lib/login_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:flutter/services.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // Cache commonly used values
  static const Duration _animationDuration = Duration(seconds: 1);
  static const Duration _gradientDuration = Duration(seconds: 2);
  static const Duration _successModalDuration = Duration(milliseconds: 600);

  // Optimize state variables
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _rememberMe = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _biometricEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<String> _selectedLanguage =
      ValueNotifier<String>('English');

  // Existing variables
  bool _gradientAnimation = false;
  final List<String> _languages = ['English', 'Laos', 'Chinese'];
  final LocalAuthentication auth = LocalAuthentication();
  late Timer _timer;
  late AnimationController _animationController;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  // Memoize expensive computations
  String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    )..repeat(reverse: true);

    // Run initialization tasks concurrently
    await Future.wait([
      _checkLocale(),
      _loadSavedCredentials(),
      _loadBiometricSetting(),
    ], eagerError: false)
        .catchError((e) {
      debugPrint('Initialization error: $e');
    });

    _startGradientAnimation();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _startGradientAnimation() {
    _timer = Timer.periodic(_gradientDuration, (timer) {
      if (mounted) {
        setState(() => _gradientAnimation = !_gradientAnimation);
      }
    });
  }

  @override
  void dispose() {
    // Cancel timers and dispose controllers
    _timer.cancel();
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();

    // Dispose ValueNotifiers
    _isLoading.dispose();
    _isPasswordVisible.dispose();
    _rememberMe.dispose();
    _biometricEnabled.dispose();
    _selectedLanguage.dispose();

    super.dispose();
  }

  Future<void> _checkLocale() async {
    String? defaultLanguage = sl<UserPreferences>().getDefaultLanguage();

    if (defaultLanguage != null && defaultLanguage.isNotEmpty) {
      setState(() {
        _selectedLanguage.value = defaultLanguage;
      });

      final languageNotifier =
          Provider.of<LanguageNotifier>(context, listen: false);
      languageNotifier.changeLanguage(defaultLanguage);
    } else {
      // If nothing saved, default to English
      setState(() {
        _selectedLanguage.value = 'English';
      });
    }
  }

  Future<void> _loadBiometricSetting() async {
    bool canCheckBiometrics = await auth.canCheckBiometrics;
    bool isDeviceSupported = await auth.isDeviceSupported();

    String? biometricEnabled = await _storage.read(key: 'biometricEnabled');
    setState(() {
      _biometricEnabled.value = (biometricEnabled == 'true') &&
          canCheckBiometrics &&
          isDeviceSupported;
    });
  }

  Future<void> _login() async {
    if (!mounted) return;

    _isLoading.value = true;
    try {
      bool isOnline = await InternetConnectionChecker().hasConnection;
      final String username = _usernameController.text.trim();
      final String password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        _showCustomDialog(
          AppLocalizations.of(context)!.loginFailed,
          AppLocalizations.of(context)!.emptyFieldsMessage,
        );
        return;
      }

      if (!isOnline) {
        _showOfflineOptionModal(
          AppLocalizations.of(context)!.noInternet,
          AppLocalizations.of(context)!.offlineMessage,
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: const <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _handleSuccessfulLogin(response);
      } else {
        _handleLoginError(response.statusCode);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        _showCustomDialog(
          AppLocalizations.of(context)!.serverError,
          AppLocalizations.of(context)!.serverErrorMessage,
        );
      }
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _handleSuccessfulLogin(http.Response response) async {
    final Map<String, dynamic> responseBody = jsonDecode(response.body);
    final String token = responseBody['token'];
    final String employeeId = responseBody['id'];

    // Run tasks concurrently
    await Future.wait([
      SharedPreferences.getInstance().then((prefs) async {
        await prefs.setString('employee_id', employeeId);
        await prefs.setBool('isFirstLogin', false);
      }),
      sl<UserPreferences>().setToken(token),
      sl<UserPreferences>().setLoggedIn(true),
      _rememberMe.value
          ? _saveCredentials(_usernameController.text.trim(),
              _passwordController.text.trim(), token)
          : _clearCredentials(),
      _storage.write(key: 'username', value: _usernameController.text.trim()),
      _storage.write(key: 'password', value: _passwordController.text.trim()),
      if (_biometricEnabled.value)
        _storage.write(key: 'biometricEnabled', value: 'true'),
    ], eagerError: false);

    if (!mounted) return;

    Provider.of<UserProvider>(context, listen: false).login(token);

    // Show success animation with optimized duration
    await _showSuccessModal();

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isFirstLogin = prefs.getBool('isFirstLogin') ?? true;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => isFirstLogin
            ? const NotificationPermissionPage()
            : const MainScreen(),
      ),
    );
  }

  void _handleLoginError(int statusCode) {
    if (!mounted) return;

    switch (statusCode) {
      case 401:
        _showCustomDialog(
          AppLocalizations.of(context)!.loginFailed,
          AppLocalizations.of(context)!.incorrectPassword,
        );
        break;
      case 500:
      case 502:
      case 403:
        _showCustomDialog(
          AppLocalizations.of(context)!.apiError,
          AppLocalizations.of(context)!.apiErrorMessage,
        );
        break;
      default:
        _showCustomDialog(
          AppLocalizations.of(context)!.loginFailed,
          AppLocalizations.of(context)!.unknownError,
        );
    }
  }

  Future<void> _showOfflineOptionModal(String title, String message) async {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double titleFontSize = constraints.maxWidth < 400 ? 18 : 24;
                double messageFontSize = constraints.maxWidth < 400 ? 14 : 18;
                double buttonFontSize = constraints.maxWidth < 400 ? 14 : 16;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: Tween(begin: -0.05, end: 0.05)
                          .animate(_animationController),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: messageFontSize,
                        color: isDarkMode ? Colors.grey[300] : Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            if (title ==
                                AppLocalizations.of(context)!.noInternet) {
                              // Allow offline login
                              await _offlineLogin();
                            } else {
                              // Prevent offline login if unauthorized
                              _showCustomDialog(
                                AppLocalizations.of(context)!.unauthorizedError,
                                AppLocalizations.of(context)!
                                    .offlineAccessDenied,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "Okay",
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
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
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).login(token);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else {
      if (mounted) {
        _showCustomDialog(
          AppLocalizations.of(context)!.loginFailed,
          AppLocalizations.of(context)!.incorrectCredentials,
        );
      }
    }
  }

  Future<void> _authenticate({bool useBiometric = true}) async {
    if (!_biometricEnabled.value) {
      _showCustomDialog(
          'Biometric Disabled', 'Please enable biometric authentication.');
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
      if (authenticated) {
        String? username = await _storage.read(key: 'username');
        String? password = await _storage.read(key: 'password');
        if (username != null && password != null) {
          _usernameController.text = username;
          _passwordController.text = password;
          _login();
        }
      } else {
        _showCustomDialog('Authentication Failed', 'Please try again.');
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
    }
  }

  Future<void> _saveCredentials(
      String username, String password, String token) async {
    final box = await Hive.openBox('loginBox');
    await box.put('username', username);
    await box.put('password', password);
    await box.put('token', token);
  }

  Future<void> _loadSavedCredentials() async {
    final box = await Hive.openBox('loginBox');
    setState(() {
      _usernameController.text =
          box.get('username', defaultValue: '') as String;
      _passwordController.text =
          box.get('password', defaultValue: '') as String;
      _rememberMe.value =
          box.containsKey('username') && box.containsKey('password');
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
      initialDate:
          Provider.of<DateProvider>(context, listen: false).selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      if (context.mounted)
        Provider.of<DateProvider>(context, listen: false)
            .updateSelectedDate(pickedDate);
    }
  }

  void _showCustomDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
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

  Future<void> _showSuccessModal() async {
    if (!mounted) return;

    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TweenAnimationBuilder(
          duration: _successModalDuration,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: AlertDialog(
                backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween<double>(begin: 0, end: 1),
                      curve: Curves.easeOutBack,
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(0.1),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 80,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Login Successful!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var languageNotifier = Provider.of<LanguageNotifier>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
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
                        _buildLanguageDropdown(
                            languageNotifier, isDarkMode, screenWidth),
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
    );
  }

  Widget _buildLanguageDropdown(
      LanguageNotifier languageNotifier, bool isDarkMode, double screenWidth) {
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
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30.0)),
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
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
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
                              onTap: () async {
                                // 1) Update local state
                                setState(() {
                                  _selectedLanguage.value = language;
                                });
                                // 2) Notify language change
                                languageNotifier.changeLanguage(language);
                                // 3) Save the new default language in UserPreferences
                                sl<UserPreferences>()
                                    .setDefaultLanguage(language);

                                // Finally close the bottom sheet
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
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/flags/${_selectedLanguage.value.toLowerCase()}.png',
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
            _selectedLanguage.value,
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start, // Aligns children to the start (left)
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
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 15),
              // Subtitle 1 with indentation
              Padding(
                padding: EdgeInsets.only(left: screenWidth * 0.04),
                child: Text(
                  AppLocalizations.of(context)!
                      .welcomeSubtitle1, // Localized Subtitle 1
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              // Subtitle 2 with further indentation
              Padding(
                padding: EdgeInsets.only(left: screenWidth * 0.08),
                child: Text(
                  AppLocalizations.of(context)!
                      .welcomeSubtitle2, // Localized Subtitle 2
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black,
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
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
          gradient: isDarkMode
              ? const LinearGradient(
                  colors: [Color(0xFF2C2C2C), Color(0xFF3A3A3A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFEE9C3), Color(0xFFFFF3D6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.5)
                  : Colors.black.withOpacity(0.1),
              offset: Offset(screenWidth * 0.005, screenWidth * 0.005),
              blurRadius: screenWidth * 0.01,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 20.0,
            ),
            SizedBox(width: screenWidth * 0.02),
            Consumer<DateProvider>(
              builder: (context, dateProvider, child) {
                return Text(
                  dateProvider.formattedSelectedDate,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    return Column(
      children: [
        SizedBox(
          width: screenWidth * 0.8,
          child: TextField(
            controller: _usernameController,
            style: TextStyle(color: isDarkMode ? Colors.black : Colors.black),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.username,
              labelStyle:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.black),
              filled: true,
              fillColor: isDarkMode ? Colors.grey : Colors.white,
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
            obscureText: !_isPasswordVisible.value,
            style: TextStyle(color: isDarkMode ? Colors.black : Colors.black),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.password,
              labelStyle:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.black),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.black,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible.value = !_isPasswordVisible.value;
                  });
                },
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.grey : Colors.white,
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      child: Row(
        children: [
          Checkbox(
            value: _rememberMe.value,
            onChanged: (bool? value) {
              setState(() {
                _rememberMe.value = value!;
              });
            },
            activeColor: Colors.green,
            checkColor: Colors.white,
          ),
          Text(
            AppLocalizations.of(context)!.rememberMe,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginAndBiometricButton(double screenWidth) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _biometricEnabled.value
                ? () => _authenticate(useBiometric: true)
                : () {
                    _showCustomDialog(
                      AppLocalizations.of(context)!.biometricDisabled,
                      AppLocalizations.of(context)!.enableBiometric,
                    );
                  },
            child: Container(
              width: screenWidth * 0.35,
              height: screenWidth * 0.125,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  color: isDarkMode ? Colors.grey : Colors.white),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face,
                      size: screenWidth * 0.09,
                      color: isDarkMode ? Colors.black : Colors.orange),
                  SizedBox(width: screenWidth * 0.025),
                  Icon(Icons.fingerprint,
                      size: screenWidth * 0.1,
                      color: isDarkMode ? Colors.black : Colors.orange),
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
                color: isDarkMode ? Colors.green : Colors.green,
              ),
              alignment: Alignment.center,
              child: Text(
                AppLocalizations.of(context)!.login,
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  color: isDarkMode ? Colors.black : Colors.white,
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
