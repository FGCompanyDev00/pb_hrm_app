// lib/settings/pin_entry_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';

class PinEntryPage extends StatefulWidget {
  const PinEntryPage({super.key});

  @override
  _PinEntryPageState createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _pinController = TextEditingController();
  final bool _obscurePin = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
  }

  // Validate entered PIN
  Future<void> _validatePin() async {
    final storedPin = await _storage.read(key: 'userPin') ?? '';

    if (_pinController.text == storedPin) {
      // Successfully entered the PIN
      Navigator.pushReplacementNamed(context, '/home'); // Replace with actual route
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
    }
  }

  // Save a new PIN to secure storage
  Future<void> _savePin(String pin) async {
    await _storage.write(key: 'userPin', value: pin);
  }

  // Limit PIN input to 6 digits
  void _onPinChanged(String pin) {
    if (pin.length > 6) {
      _pinController.text = pin.substring(0, 6);
      _pinController.selection = TextSelection.collapsed(offset: _pinController.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                themeNotifier.isDarkMode ? 'assets/darkbg.png' : 'assets/background.png',
              ),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'PIN Entry',
          style: TextStyle(
            color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 100,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Please enter your 6-digit PIN',
              style: TextStyle(
                fontSize: 18,
                color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: _onPinChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: themeNotifier.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                labelText: 'PIN',
                labelStyle: TextStyle(
                  color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                counterText: '',
              ),
              style: TextStyle(
                color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _validatePin,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  themeNotifier.isDarkMode ? Colors.greenAccent : Colors.green,
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
              ),
              child: Text(
                'Submit',
                style: TextStyle(
                  fontSize: 16,
                  color: themeNotifier.isDarkMode ? Colors.white : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
