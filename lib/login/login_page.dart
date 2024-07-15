import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/login/notification_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _gradientAnimation = false;
  String _selectedLanguage = 'English'; // Default language
  final List<String> _languages = ['English', 'Laos', 'Chinese'];
  late Timer _timer;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startGradientAnimation();
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
      jsonDecode(response.body);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${response.reasonPhrase}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var languageNotifier = Provider.of<LanguageNotifier>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                _buildLanguageDropdown(languageNotifier),
                const SizedBox(height: 10),
                _buildLogoAndText(context),
                const SizedBox(height: 40),
                _buildDateRow(),
                const SizedBox(height: 40),
                _buildTextFields(context),
                const SizedBox(height: 20),
                _buildRememberMeCheckbox(context),
                const SizedBox(height: 20),
                _buildLoginButton(context),
                const SizedBox(height: 20),
                _buildAuthenticationIcons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(LanguageNotifier languageNotifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: DropdownButton<String>(
        value: _selectedLanguage,
        icon: const Icon(Icons.arrow_downward),
        iconSize: 24,
        elevation: 16,
        style: const TextStyle(color: Colors.black, fontSize: 18),
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
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogoAndText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/logo.png',
          width: 200,
          height: 150,
        ),
        const SizedBox(height: 30),
        Text(
          AppLocalizations.of(context)!.welcomeToPBHR,
          style: const TextStyle(
            fontSize: 24,
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

  Widget _buildDateRow() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.calendar_today, color: Colors.black),
        SizedBox(width: 8),
        Text(
          "21 MAR 2024",
          style: TextStyle(fontSize: 16, color: Colors.black),
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
            prefixIcon: const Icon(Icons.person, color: Colors.black),
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
          obscureText: true,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.password,
            labelStyle: const TextStyle(color: Colors.black),
            prefixIcon: const Icon(Icons.lock, color: Colors.black),
            suffixIcon: const Icon(Icons.visibility, color: Colors.black),
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
          value: true,
          onChanged: (bool? value) {},
          activeColor: Colors.white,
          checkColor: Colors.black,
        ),
        Text(AppLocalizations.of(context)!.rememberMe, style: const TextStyle(color: Colors.black)),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: _login,
        child: AnimatedContainer(
          duration: const Duration(seconds: 2),
          width: 200,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            gradient: LinearGradient(
              colors: _gradientAnimation
                  ? [Colors.blue, Colors.purple]
                  : [Colors.purple, Colors.blue],
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
    );
  }

  Widget _buildAuthenticationIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.network(
          'https://img.icons8.com/ios-filled/50/ffffff/fingerprint.png',
          width: 40,
          height: 40,
        ),
        const SizedBox(width: 20),
        Image.network(
          'https://img.icons8.com/ios-filled/50/ffffff/face-id.png',
          width: 40,
          height: 40,
        ),
      ],
    );
  }
}
