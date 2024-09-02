// // import 'dart:async';
// // import 'dart:convert';
// // import 'package:flutter/foundation.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// // import 'package:pb_hrsystem/login/forgot_password_page.dart';
// // import 'package:pb_hrsystem/login/notification_page.dart';
// // import 'package:pb_hrsystem/main.dart';
// // import 'package:provider/provider.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:intl/intl.dart';
// // import 'package:local_auth/local_auth.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// // import 'package:pb_hrsystem/theme/theme.dart';

// // class LoginPage extends StatefulWidget {
// //   const LoginPage({super.key});

// //   @override
// //   _LoginPageState createState() => _LoginPageState();
// // }

// // class _LoginPageState extends State<LoginPage> {
// //   bool _gradientAnimation = false;
// //   String _selectedLanguage = 'English'; // Default language
// //   final List<String> _languages = ['English', 'Laos', 'Chinese'];
// //   final LocalAuthentication auth = LocalAuthentication();
// //   bool _rememberMe = false;
// //   bool _isPasswordVisible = false; // State variable for password visibility
// //   bool _biometricEnabled = false; // Biometric setting
// //   late Timer _timer;
// //   final TextEditingController _usernameController = TextEditingController();
// //   final TextEditingController _passwordController = TextEditingController();
// //   final _storage = const FlutterSecureStorage(); // Secure storage instance

// //   @override
// //   void initState() {
// //     super.initState();
// //     _startGradientAnimation();
// //     _loadSavedCredentials();
// //     _loadBiometricSetting();
// //   }

// //   @override
// //   void dispose() {
// //     _timer.cancel(); // Cancel the timer when disposing the widget
// //     _usernameController.dispose();
// //     _passwordController.dispose();
// //     super.dispose();
// //   }

// //   void _startGradientAnimation() {
// //     _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
// //       if (mounted) {
// //         setState(() {
// //           _gradientAnimation = !_gradientAnimation;
// //         });
// //       }
// //     });
// //   }

// //   Future<void> _loadBiometricSetting() async {
// //     String? biometricEnabled = await _storage.read(key: 'biometricEnabled');
// //     setState(() {
// //       _biometricEnabled = biometricEnabled == 'true';
// //     });
// //   }

// //   Future<void> _login() async {
// //     final String username = _usernameController.text;
// //     final String password = _passwordController.text;

// //     final response = await http.post(
// //       Uri.parse('https://demo-application-api.flexiflows.co/api/login'),
// //       headers: <String, String>{
// //         'Content-Type': 'application/json; charset=UTF-8',
// //       },
// //       body: jsonEncode(<String, String>{
// //         'username': username,
// //         'password': password,
// //       }),
// //     );

// //     if (response.statusCode == 200) {
// //       final Map<String, dynamic> responseBody = jsonDecode(response.body);
// //       final String token = responseBody['token'];

// //       final prefs = await SharedPreferences.getInstance();
// //       await prefs.setString('token', token); // Save token

// //       if (_rememberMe) {
// //         _saveCredentials();
// //       } else {
// //         _clearCredentials();
// //       }

// //       // Save the credentials securely if biometric is enabled
// //       if (_biometricEnabled) {
// //         await _storage.write(key: 'username', value: username);
// //         await _storage.write(key: 'password', value: password);
// //         await _storage.write(key: 'biometricEnabled', value: 'true');
// //       }

// //       // Check if it's the first login on this device
// //       bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;
// //       if (kDebugMode) {
// //         print('isFirstLogin: $isFirstLogin');
// //       } // Debug print to check the value

// //       if (isFirstLogin) {
// //         Navigator.pushReplacement(
// //           context,
// //           MaterialPageRoute(builder: (context) => const NotificationPage()),
// //         );
// //         await prefs.setBool('isFirstLogin', false);
// //       } else {
// //         Navigator.pushReplacement(
// //           context,
// //           MaterialPageRoute(builder: (context) => const MainScreen()),
// //         );
// //       }
// //     } else {
// //       _showCustomDialog(
// //           context,
// //           AppLocalizations.of(context)!.loginFailed,
// //           '${AppLocalizations.of(context)!.loginFailedMessage} ${response.reasonPhrase}'
// //       );
// //     }
// //   }

// //   // Future<void> _authenticate({bool useBiometric = true}) async {
// //   //   if (!_biometricEnabled) {
// //   //     _showCustomDialog(context, AppLocalizations.of(context)!.biometricDisabled, AppLocalizations.of(context)!.enableBiometric);
// //   //     return;
// //   //   }

// //   //   bool authenticated = false;
// //   //   try {
// //   //     authenticated = await auth.authenticate(
// //   //       localizedReason: AppLocalizations.of(context)!.authenticateToLogin,
// //   //       options: AuthenticationOptions(
// //   //         biometricOnly: useBiometric,
// //   //         stickyAuth: true,
// //   //       ),
// //   //     );
// //   //   } catch (e) {
// //   //     if (kDebugMode) {
// //   //       print(e);
// //   //     }
// //   //   }

// //   //   if (authenticated) {
// //   //     String? username = await _storage.read(key: 'username');
// //   //     String? password = await _storage.read(key: 'password');
// //   //     if (username != null && password != null) {
// //   //       _usernameController.text = username;
// //   //       _passwordController.text = password;
// //   //       _login(); // Login automatically using stored credentials
// //   //     }
// //   //   } else {
// //   //     _showCustomDialog(context, AppLocalizations.of(context)!.authFailed, AppLocalizations.of(context)!.tryAgain);
// //   //   }
// //   // }

// //   Future<void> _authenticate({bool useBiometric = true}) async {
// //     if (!_biometricEnabled) {
// //         _showCustomDialog(context, 'Biometric Disabled', 'Please enable biometric authentication.');
// //         return;
// //     }

// //     bool authenticated = false;
// //     try {
// //         authenticated = await auth.authenticate(
// //             localizedReason: 'Authenticate to login',
// //             options: AuthenticationOptions(
// //                 biometricOnly: useBiometric,
// //                 stickyAuth: true,
// //             ),
// //         );
// //     } catch (e) {
// //         if (kDebugMode) {
// //             print('Authentication error: $e');
// //         }
// //     }

// //     if (authenticated) {
// //         String? username = await _storage.read(key: 'username');
// //         String? password = await _storage.read(key: 'password');
// //         if (username != null && password != null) {
// //             _usernameController.text = username;
// //             _passwordController.text = password;
// //             _login();
// //         }
// //     } else {
// //         _showCustomDialog(context, 'Authentication Failed', 'Please try again.');
// //     }
// // }


// //   Future<void> _saveCredentials() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     prefs.setString('username', _usernameController.text);
// //     prefs.setString('password', _passwordController.text);
// //     prefs.setBool('rememberMe', _rememberMe);
// //   }

// //   Future<void> _loadSavedCredentials() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     setState(() {
// //       _usernameController.text = prefs.getString('username') ?? '';
// //       _passwordController.text = prefs.getString('password') ?? '';
// //       _rememberMe = prefs.getBool('rememberMe') ?? false;
// //     });
// //   }

// //   Future<void> _clearCredentials() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     prefs.remove('username');
// //     prefs.remove('password');
// //     prefs.remove('rememberMe');
// //   }

// //   void _showCustomDialog(BuildContext context, String title, String message) {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //           content: Column(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               const Icon(Icons.info, color: Colors.red, size: 50),
// //               const SizedBox(height: 16),
// //               Text(
// //                 title,
// //                 style: const TextStyle(
// //                   fontSize: 22,
// //                   fontWeight: FontWeight.bold,
// //                 ),
// //               ),
// //               const SizedBox(height: 16),
// //               Text(
// //                 message,
// //                 style: const TextStyle(fontSize: 18),
// //               ),
// //               const SizedBox(height: 16),
// //               ElevatedButton(
// //                 onPressed: () {
// //                   Navigator.of(context).pop();
// //                 },
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor: const Color(0xFFDAA520), // gold color
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(8.0),
// //                   ),
// //                 ),
// //                 child: const Text('Close'),
// //               ),
// //             ],
// //           ),
// //         );
// //       },
// //     );
// //   }

// //   Widget _buildForgotPasswordButton(BuildContext context) {
// //     return TextButton(
// //       onPressed: () {
// //         Navigator.push(
// //           context,
// //           MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
// //         );
// //       },
// //       child: Text(
// //         AppLocalizations.of(context)!.forgotPassword,
// //         style: const TextStyle(color: Colors.black),
// //       ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     var languageNotifier = Provider.of<LanguageNotifier>(context);
// //     var currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());
// //     final themeNotifier = Provider.of<ThemeNotifier>(context);
// //     final bool isDarkMode = themeNotifier.isDarkMode;

// //     return Scaffold(
// //       body: SafeArea(
// //         child: Container(
// //           width: double.infinity,
// //           height: double.infinity,
// //           decoration: const BoxDecoration(
// //             image: DecorationImage(
// //               image: AssetImage('assets/background.png'),
// //               fit: BoxFit.cover,
// //             ),
// //           ),
// //           child: Center(
// //             child: SingleChildScrollView(
// //               padding: const EdgeInsets.symmetric(horizontal: 24.0),
// //               child: ConstrainedBox(
// //                 constraints: BoxConstraints(
// //                   minHeight: MediaQuery.of(context).size.height,
// //                 ),
// //                 child: IntrinsicHeight(
// //                   child: Column(
// //                     mainAxisAlignment: MainAxisAlignment.center,
// //                     children: [
// //                       _buildLanguageDropdown(languageNotifier, isDarkMode),
// //                       const SizedBox(height: 20),
// //                       _buildLogoAndText(context),
// //                       const SizedBox(height: 20),
// //                       _buildDateRow(currentDate),
// //                       const SizedBox(height: 40),
// //                       _buildTextFields(context),
// //                       const SizedBox(height: 20),
// //                       _buildRememberMeCheckbox(context),
// //                       const SizedBox(height: 20),
// //                       _buildLoginButton(context),
// //                       _buildForgotPasswordButton(context),
// //                       const SizedBox(height: 20),
// //                       _buildAuthenticationIcons(),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildLanguageDropdown(LanguageNotifier languageNotifier, bool isDarkMode) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
// //       decoration: BoxDecoration(
// //         color: isDarkMode ? Colors.black54 : Colors.white,
// //         borderRadius: BorderRadius.circular(8.0),
// //         boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
// //       ),
// //       child: DropdownButton<String>(
// //         value: _selectedLanguage,
// //         dropdownColor: isDarkMode ? Colors.black54 : Colors.white,
// //         icon: Icon(Icons.arrow_downward, color: isDarkMode ? Colors.white : Colors.black),
// //         iconSize: 24,
// //         elevation: 16,
// //         style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18),
// //         underline: Container(
// //           height: 2,
// //           color: Colors.transparent,
// //         ),
// //         onChanged: (String? newValue) {
// //           setState(() {
// //             _selectedLanguage = newValue!;
// //           });
// //           languageNotifier.changeLanguage(newValue!);
// //         },
// //         items: _languages.map<DropdownMenuItem<String>>((String value) {
// //           return DropdownMenuItem<String>(
// //             value: value,
// //             child: Row(
// //               children: [
// //                 Image.asset(
// //                   'assets/flags/${value.toLowerCase()}.png',
// //                   width: 24,
// //                   height: 24,
// //                 ),
// //                 const SizedBox(width: 8),
// //                 Text(value),
// //               ],
// //             ),
// //           );
// //         }).toList(),
// //       ),
// //     );
// //   }

// //   Widget _buildLogoAndText(BuildContext context) {
// //     return Column(
// //       crossAxisAlignment: CrossAxisAlignment.center,
// //       children: [
// //         Image.asset(
// //           'assets/logo.png',
// //           width: 150,
// //           height: 100,
// //         ),
// //         const SizedBox(height: 30),
// //         Text(
// //           AppLocalizations.of(context)!.welcomeToPSBV,
// //           style: const TextStyle(
// //             fontSize: 22,
// //             fontWeight: FontWeight.bold,
// //             color: Colors.black,
// //           ),
// //         ),
// //         const SizedBox(height: 8),
// //         Text(
// //           AppLocalizations.of(context)!.notJustAnotherCustomer,
// //           textAlign: TextAlign.center,
// //           style: const TextStyle(
// //             fontSize: 16,
// //             color: Colors.black,
// //           ),
// //         ),
// //       ],
// //     );
// //   }

// //   Widget _buildDateRow(String currentDate) {
// //     return Row(
// //       mainAxisAlignment: MainAxisAlignment.center,
// //       children: [
// //         const Icon(Icons.calendar_today, color: Colors.black),
// //         const SizedBox(width: 8),
// //         Text(
// //           currentDate,
// //           style: const TextStyle(fontSize: 16, color: Colors.black),
// //         ),
// //       ],
// //     );
// //   }

// //   Widget _buildTextFields(BuildContext context) {
// //     return Column(
// //       children: [
// //         TextField(
// //           controller: _usernameController,
// //           style: const TextStyle(color: Colors.black),
// //           decoration: InputDecoration(
// //             labelText: AppLocalizations.of(context)!.username,
// //             labelStyle: const TextStyle(color: Colors.black),
// //             prefixIcon: const Icon(Icons.person, color: Colors.black),
// //             filled: true,
// //             fillColor: Colors.white.withOpacity(0.8),
// //             border: OutlineInputBorder(
// //               borderRadius: BorderRadius.circular(8.0),
// //               borderSide: BorderSide.none,
// //             ),
// //           ),
// //         ),
// //         const SizedBox(height: 20),
// //         TextField(
// //           controller: _passwordController,
// //           obscureText: !_isPasswordVisible,
// //           style: const TextStyle(color: Colors.black),
// //           decoration: InputDecoration(
// //             labelText: AppLocalizations.of(context)!.password,
// //             labelStyle: const TextStyle(color: Colors.black),
// //             prefixIcon: const Icon(Icons.lock, color: Colors.black),
// //             suffixIcon: IconButton(
// //               icon: Icon(
// //                 _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
// //                 color: Colors.black,
// //               ),
// //               onPressed: () {
// //                 setState(() {
// //                   _isPasswordVisible = !_isPasswordVisible;
// //                 });
// //               },
// //             ),
// //             filled: true,
// //             fillColor: Colors.white.withOpacity(0.8),
// //             border: OutlineInputBorder(
// //               borderRadius: BorderRadius.circular(8.0),
// //               borderSide: BorderSide.none,
// //             ),
// //           ),
// //         ),
// //       ],
// //     );
// //   }

// //   Widget _buildRememberMeCheckbox(BuildContext context) {
// //     return Row(
// //       children: [
// //         Checkbox(
// //           value: _rememberMe,
// //           onChanged: (bool? value) {
// //             setState(() {
// //               _rememberMe = value!;
// //             });
// //           },
// //           activeColor: Colors.white,
// //           checkColor: Colors.black,
// //         ),
// //         Text(AppLocalizations.of(context)!.rememberMe, style: const TextStyle(color: Colors.black)),
// //       ],
// //     );
// //   }

// //   Widget _buildLoginButton(BuildContext context) {
// //     return Center(
// //       child: GestureDetector(
// //         onTap: _login,
// //         child: AnimatedContainer(
// //           duration: const Duration(seconds: 2),
// //           width: MediaQuery.of(context).size.width * 0.6,
// //           height: 50,
// //           decoration: BoxDecoration(
// //             borderRadius: BorderRadius.circular(8.0),
// //             gradient: LinearGradient(
// //               colors: _gradientAnimation
// //                   ? [Colors.blue, Colors.purple]
// //                   : [Colors.purple, Colors.blue],
// //               begin: Alignment.topLeft,
// //               end: Alignment.bottomRight,
// //             ),
// //             boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
// //           ),
// //           alignment: Alignment.center,
// //           child: Text(
// //             AppLocalizations.of(context)!.login,
// //             style: const TextStyle(
// //               fontSize: 18,
// //               color: Colors.white,
// //               fontWeight: FontWeight.bold,
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildAuthenticationIcons() {
// //     return Row(
// //       mainAxisAlignment: MainAxisAlignment.center,
// //       children: [
// //         GestureDetector(
// //           onTap: _biometricEnabled ? () => _authenticate(useBiometric: true) : () {
// //             _showCustomDialog(context, AppLocalizations.of(context)!.biometricDisabled, AppLocalizations.of(context)!.enableBiometric);
// //           },
// //           child: const Icon(Icons.fingerprint, size: 40, color: Colors.black),
// //         ),
// //         const SizedBox(width: 20),
// //         GestureDetector(
// //           onTap: _biometricEnabled ? () => _authenticate(useBiometric: false) : () {
// //             _showCustomDialog(context, AppLocalizations.of(context)!.biometricDisabled, AppLocalizations.of(context)!.enableBiometric);
// //           },
// //           child: const Icon(Icons.face, size: 40, color: Colors.black),
// //         ),
// //       ],
// //     );
// //   }
// // }

// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:pb_hrsystem/login/forgot_password_page.dart';
// import 'package:pb_hrsystem/login/notification_page.dart';
// import 'package:pb_hrsystem/main.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:local_auth/local_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:pb_hrsystem/theme/theme.dart';
// import 'package:flutter/services.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   _LoginPageState createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   bool _gradientAnimation = false;
//   String _selectedLanguage = 'English'; // Default language
//   final List<String> _languages = ['English', 'Laos', 'Chinese'];
//   final LocalAuthentication auth = LocalAuthentication();
//   bool _rememberMe = false;
//   bool _isPasswordVisible = false; // State variable for password visibility
//   bool _biometricEnabled = false; // Biometric setting
//   late Timer _timer;
//   final TextEditingController _usernameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final _storage = const FlutterSecureStorage(); // Secure storage instance

//   @override
//   void initState() {
//     super.initState();
//     _startGradientAnimation();
//     _loadSavedCredentials();
//     _loadBiometricSetting();
//     // Make the app full-screen (optional, depending on your needs)
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//   }

//   @override
//   void dispose() {
//     _timer.cancel(); // Cancel the timer when disposing the widget
//     _usernameController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   void _startGradientAnimation() {
//     _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
//       if (mounted) {
//         setState(() {
//           _gradientAnimation = !_gradientAnimation;
//         });
//       }
//     });
//   }

//   Future<void> _loadBiometricSetting() async {
//     String? biometricEnabled = await _storage.read(key: 'biometricEnabled');
//     setState(() {
//       _biometricEnabled = biometricEnabled == 'true';
//     });
//   }

//   Future<void> _login() async {
//     final String username = _usernameController.text;
//     final String password = _passwordController.text;

//     final response = await http.post(
//       Uri.parse('https://demo-application-api.flexiflows.co/api/login'),
//       headers: <String, String>{
//         'Content-Type': 'application/json; charset=UTF-8',
//       },
//       body: jsonEncode(<String, String>{
//         'username': username,
//         'password': password,
//       }),
//     );

//     if (response.statusCode == 200) {
//       final Map<String, dynamic> responseBody = jsonDecode(response.body);
//       final String token = responseBody['token'];

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('token', token); // Save token

//       if (_rememberMe) {
//         _saveCredentials();
//       } else {
//         _clearCredentials();
//       }

//       // Save the credentials securely if biometric is enabled
//       if (_biometricEnabled) {
//         await _storage.write(key: 'username', value: username);
//         await _storage.write(key: 'password', value: password);
//         await _storage.write(key: 'biometricEnabled', value: 'true');
//       }

//       // Check if it's the first login on this device
//       bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;
//       if (kDebugMode) {
//         print('isFirstLogin: $isFirstLogin');
//       } // Debug print to check the value

//       if (isFirstLogin) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const NotificationPage()),
//         );
//         await prefs.setBool('isFirstLogin', false);
//       } else {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const MainScreen()),
//         );
//       }
//     } else {
//       _showCustomDialog(
//           context,
//           AppLocalizations.of(context)!.loginFailed,
//           '${AppLocalizations.of(context)!.loginFailedMessage} ${response.reasonPhrase}'
//       );
//     }
//   }

//   Future<void> _authenticate({bool useBiometric = true}) async {
//     if (!_biometricEnabled) {
//       _showCustomDialog(context, 'Biometric Disabled', 'Please enable biometric authentication.');
//       return;
//     }

//     bool authenticated = false;
//     try {
//       authenticated = await auth.authenticate(
//         localizedReason: 'Authenticate to login',
//         options: AuthenticationOptions(
//           biometricOnly: useBiometric,
//           stickyAuth: true,
//         ),
//       );
//     } catch (e) {
//       if (kDebugMode) {
//         print('Authentication error: $e');
//       }
//     }

//     if (authenticated) {
//       String? username = await _storage.read(key: 'username');
//       String? password = await _storage.read(key: 'password');
//       if (username != null && password != null) {
//         _usernameController.text = username;
//         _passwordController.text = password;
//         _login();
//       }
//     } else {
//       _showCustomDialog(context, 'Authentication Failed', 'Please try again.');
//     }
//   }

//   Future<void> _saveCredentials() async {
//     final prefs = await SharedPreferences.getInstance();
//     prefs.setString('username', _usernameController.text);
//     prefs.setString('password', _passwordController.text);
//     prefs.setBool('rememberMe', _rememberMe);
//   }

//   Future<void> _loadSavedCredentials() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _usernameController.text = prefs.getString('username') ?? '';
//       _passwordController.text = prefs.getString('password') ?? '';
//       _rememberMe = prefs.getBool('rememberMe') ?? false;
//     });
//   }

//   Future<void> _clearCredentials() async {
//     final prefs = await SharedPreferences.getInstance();
//     prefs.remove('username');
//     prefs.remove('password');
//     prefs.remove('rememberMe');
//   }

//   void _showCustomDialog(BuildContext context, String title, String message) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.info, color: Colors.red, size: 50),
//               const SizedBox(height: 16),
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 message,
//                 style: const TextStyle(fontSize: 18),
//               ),
//               const SizedBox(height: 16),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFFDAA520), // gold color
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8.0),
//                   ),
//                 ),
//                 child: const Text('Close'),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildForgotPasswordButton(BuildContext context) {
//     return TextButton(
//       onPressed: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
//         );
//       },
//       child: Text(
//         AppLocalizations.of(context)!.forgotPassword,
//         style: const TextStyle(color: Colors.black),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     var languageNotifier = Provider.of<LanguageNotifier>(context);
//     var currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());
//     final themeNotifier = Provider.of<ThemeNotifier>(context);
//     final bool isDarkMode = themeNotifier.isDarkMode;

//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       body: Container(
//         width: double.infinity,
//         height: double.infinity,
//         decoration: const BoxDecoration(
//           image: DecorationImage(
//             image: AssetImage('assets/background.png'),
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: Center(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.symmetric(horizontal: 24.0),
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 minHeight: MediaQuery.of(context).size.height,
//               ),
//               child: IntrinsicHeight(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     _buildLanguageDropdown(languageNotifier, isDarkMode),
//                     const SizedBox(height: 20),
//                     _buildLogoAndText(context),
//                     const SizedBox(height: 20),
//                     _buildDateRow(currentDate),
//                     const SizedBox(height: 40),
//                     _buildTextFields(context),
//                     const SizedBox(height: 20),
//                     _buildRememberMeCheckbox(context),
//                     const SizedBox(height: 20),
//                     _buildLoginButton(context),
//                     _buildForgotPasswordButton(context),
//                     const SizedBox(height: 20),
//                     _buildAuthenticationIcons(),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildLanguageDropdown(LanguageNotifier languageNotifier, bool isDarkMode) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       decoration: BoxDecoration(
//         color: isDarkMode ? Colors.black54 : Colors.white,
//         borderRadius: BorderRadius.circular(8.0),
//         boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
//       ),
//       child: DropdownButton<String>(
//         value: _selectedLanguage,
//         dropdownColor: isDarkMode ? Colors.black54 : Colors.white,
//         icon: Icon(Icons.arrow_downward, color: isDarkMode ? Colors.white : Colors.black),
//         iconSize: 24,
//         elevation: 16,
//         style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18),
//         underline: Container(
//           height: 2,
//           color: Colors.transparent,
//         ),
//         onChanged: (String? newValue) {
//           setState(() {
//             _selectedLanguage = newValue!;
//           });
//           languageNotifier.changeLanguage(newValue!);
//         },
//         items: _languages.map<DropdownMenuItem<String>>((String value) {
//           return DropdownMenuItem<String>(
//             value: value,
//             child: Row(
//               children: [
//                 Image.asset(
//                   'assets/flags/${value.toLowerCase()}.png',
//                   width: 24,
//                   height: 24,
//                 ),
//                 const SizedBox(width: 8),
//                 Text(value),
//               ],
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   Widget _buildLogoAndText(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Image.asset(
//           'assets/logo.png',
//           width: 150,
//           height: 100,
//         ),
//         const SizedBox(height: 30),
//         Text(
//           AppLocalizations.of(context)!.welcomeToPSBV,
//           style: const TextStyle(
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           AppLocalizations.of(context)!.notJustAnotherCustomer,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             fontSize: 16,
//             color: Colors.black,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildDateRow(String currentDate) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         const Icon(Icons.calendar_today, color: Colors.black),
//         const SizedBox(width: 8),
//         Text(
//           currentDate,
//           style: const TextStyle(fontSize: 16, color: Colors.black),
//         ),
//       ],
//     );
//   }

//   Widget _buildTextFields(BuildContext context) {
//     return Column(
//       children: [
//         TextField(
//           controller: _usernameController,
//           style: const TextStyle(color: Colors.black),
//           decoration: InputDecoration(
//             labelText: AppLocalizations.of(context)!.username,
//             labelStyle: const TextStyle(color: Colors.black),
//             prefixIcon: const Icon(Icons.person, color: Colors.black),
//             filled: true,
//             fillColor: Colors.white.withOpacity(0.8),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8.0),
//               borderSide: BorderSide.none,
//             ),
//           ),
//         ),
//         const SizedBox(height: 20),
//         TextField(
//           controller: _passwordController,
//           obscureText: !_isPasswordVisible,
//           style: const TextStyle(color: Colors.black),
//           decoration: InputDecoration(
//             labelText: AppLocalizations.of(context)!.password,
//             labelStyle: const TextStyle(color: Colors.black),
//             prefixIcon: const Icon(Icons.lock, color: Colors.black),
//             suffixIcon: IconButton(
//               icon: Icon(
//                 _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
//                 color: Colors.black,
//               ),
//               onPressed: () {
//                 setState(() {
//                   _isPasswordVisible = !_isPasswordVisible;
//                 });
//               },
//             ),
//             filled: true,
//             fillColor: Colors.white.withOpacity(0.8),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8.0),
//               borderSide: BorderSide.none,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildRememberMeCheckbox(BuildContext context) {
//     return Row(
//       children: [
//         Checkbox(
//           value: _rememberMe,
//           onChanged: (bool? value) {
//             setState(() {
//               _rememberMe = value!;
//             });
//           },
//           activeColor: Colors.white,
//           checkColor: Colors.black,
//         ),
//         Text(AppLocalizations.of(context)!.rememberMe, style: const TextStyle(color: Colors.black)),
//       ],
//     );
//   }

//   Widget _buildLoginButton(BuildContext context) {
//     return Center(
//       child: GestureDetector(
//         onTap: _login,
//         child: AnimatedContainer(
//           duration: const Duration(seconds: 2),
//           width: MediaQuery.of(context).size.width * 0.6,
//           height: 50,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(8.0),
//             gradient: LinearGradient(
//               colors: _gradientAnimation
//                   ? [Colors.blue, Colors.purple]
//                   : [Colors.purple, Colors.blue],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             AppLocalizations.of(context)!.login,
//             style: const TextStyle(
//               fontSize: 18,
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildAuthenticationIcons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         GestureDetector(
//           onTap: _biometricEnabled ? () => _authenticate(useBiometric: true) : () {
//             _showCustomDialog(context, AppLocalizations.of(context)!.biometricDisabled, AppLocalizations.of(context)!.enableBiometric);
//           },
//           child: const Icon(Icons.fingerprint, size: 40, color: Colors.black),
//         ),
//         const SizedBox(width: 20),
//         GestureDetector(
//           onTap: _biometricEnabled ? () => _authenticate(useBiometric: false) : () {
//             _showCustomDialog(context, AppLocalizations.of(context)!.biometricDisabled, AppLocalizations.of(context)!.enableBiometric);
//           },
//           child: const Icon(Icons.face, size: 40, color: Colors.black),
//         ),
//       ],
//     );
//   }
// }


import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/login/forgot_password_page.dart';
import 'package:pb_hrsystem/login/notification_page.dart';
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
          MaterialPageRoute(builder: (context) => const NotificationPage()),
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
          '${AppLocalizations.of(context)!.loginFailedMessage} ${response.reasonPhrase}'
      );
    }
  }

  Future<void> _authenticate({bool useBiometric = true}) async {
    if (!_biometricEnabled) {
      _showCustomDialog(context, 'Biometric Disabled', 'Please enable biometric authentication.');
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
        style: const TextStyle(color: Colors.black),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLanguageDropdown(languageNotifier, isDarkMode),
                    const SizedBox(height: 20),
                    _buildLogoAndText(context),
                    const SizedBox(height: 20),
                    _buildDateRow(currentDate),
                    const SizedBox(height: 40),
                    _buildTextFields(context),
                    const SizedBox(height: 20),
                    _buildRememberMeCheckbox(context),
                    const SizedBox(height: 20),
                    _buildLoginAndBiometricButton(context),
                    _buildForgotPasswordButton(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(LanguageNotifier languageNotifier, bool isDarkMode) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black54 : Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: DropdownButton<String>(
          value: _selectedLanguage,
          dropdownColor: isDarkMode ? Colors.black54 : Colors.white,
          icon: Icon(Icons.arrow_downward, color: isDarkMode ? Colors.white : Colors.black),
          iconSize: 24,
          elevation: 16,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18),
          underline: Container(
            height: 2,
            color: Colors.transparent,
          ),
          onChanged: (String? newValue) {
            setState(() {
              _selectedLanguage = newValue!;
            });
            languageNotifier.changeLanguage(newValue!);
          },
          items: _languages.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Image.asset(
                    'assets/flags/${value.toLowerCase()}.png',
                    width: 28,
                    height: 26,
                  ),
                  const SizedBox(width: 12),
                  Text(value),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLogoAndText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/playstore.png',
          width: 150,
          height: 100,
        ),
        const SizedBox(height: 40),
        Text(
          AppLocalizations.of(context)!.welcomeToPSBV,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.notJustAnotherCustomer,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow(String currentDate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calendar_today, color: Colors.black),
        const SizedBox(width: 8),
        Text(
          currentDate,
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildTextFields(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.username,
            labelStyle: const TextStyle(color: Colors.black),
            prefixIcon: const Icon(Icons.person_outline, color: Colors.black),
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
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
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMeCheckbox(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (bool? value) {
            setState(() {
              _rememberMe = value!;
            });
          },
          activeColor: Colors.white,
          checkColor: Colors.black,
        ),
        Text(AppLocalizations.of(context)!.rememberMe, style: const TextStyle(color: Colors.black)),
      ],
    );
  }

  Widget _buildLoginAndBiometricButton(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _biometricEnabled ? () => _authenticate(useBiometric: true) : () {
            _showCustomDialog(context, AppLocalizations.of(context)!.biometricDisabled, AppLocalizations.of(context)!.enableBiometric);
          },
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              color: Colors.grey[300],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.face, size: 24, color: Colors.orange),
                SizedBox(width: 10),
                Icon(Icons.fingerprint, size: 24, color: Colors.orange),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: _login,
          child: AnimatedContainer(
            duration: const Duration(seconds: 2),
            width: MediaQuery.of(context).size.width * 0.4, // Adjust the width as needed
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.green], // Make the login button green
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
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
    );
  }
}
