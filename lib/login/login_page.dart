import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/login/notification_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _gradientAnimation = false;
  String _selectedLanguage = 'English'; // Default language
  final List<String> _languages = ['English', 'Laos', 'Chinese'];
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startGradientAnimation();
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when disposing the widget
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
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
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
                    languageNotifier.changeLanguage(newValue!); // Pass the selected language directly
                  },
                  items: _languages.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 200,
                          height: 150,
                        ),
                        const SizedBox(height: 30),
                        Text(
                          AppLocalizations.of(context)!.welcomeToPSVB,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "You're not just another customer.\nWe're not just another Bank...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, color: Colors.black),
                            SizedBox(width: 8),
                            Text(
                              "21 MAR 2024",
                              style: TextStyle(fontSize: 16, color: Colors.black),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        TextField(
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.username,
                            labelStyle: const TextStyle(color: Colors.black),
                            prefixIcon: const Icon(Icons.person, color: Colors.black),
                            filled: true,
                            fillColor: Colors.white24,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          obscureText: true,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.password,
                            labelStyle: const TextStyle(color: Colors.black),
                            prefixIcon: const Icon(Icons.lock, color: Colors.black),
                            suffixIcon: const Icon(Icons.visibility, color: Colors.black),
                            filled: true,
                            fillColor: Colors.white24,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Checkbox(
                              value: true,
                              onChanged: (bool? value) {},
                              activeColor: Colors.white,
                              checkColor: Colors.black,
                            ),
                            const Text("Remember Me", style: TextStyle(color: Colors.black)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationPage()));
                            },
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
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                "LOGIN",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
