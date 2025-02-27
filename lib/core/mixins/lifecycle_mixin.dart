import 'package:flutter/material.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:provider/provider.dart';

mixin AppLifecycleMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  bool _isPaused = false;
  bool _isResuming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        // Handle when app becomes inactive (e.g., receiving a phone call)
        break;
      case AppLifecycleState.detached:
        // Handle when app is detached (terminated but instance maintained)
        break;
      default:
        break;
    }
  }

  // Implement other required methods from WidgetsBindingObserver
  @override
  void didChangeAccessibilityFeatures() {}

  @override
  void didChangeLocales(List<Locale>? locales) {}

  @override
  void didChangeMetrics() {}

  @override
  void didChangePlatformBrightness() {}

  @override
  void didChangeTextScaleFactor() {}

  @override
  void didHaveMemoryPressure() {}

  @override
  Future<bool> didPopRoute() async => false;

  @override
  Future<bool> didPushRoute(String route) async => false;

  @override
  Future<bool> didPushRouteInformation(
          RouteInformation routeInformation) async =>
      false;

  Future<void> _handleAppPaused() async {
    _isPaused = true;
    // Save any critical state here
    await _saveAppState();
  }

  Future<void> _handleAppResumed() async {
    if (_isPaused && !_isResuming) {
      _isResuming = true;
      try {
        // Check internet connectivity
        bool isOnline = await InternetConnectionChecker().hasConnection;

        if (isOnline) {
          // Verify and refresh token if needed
          await _refreshSessionIfNeeded();
        }

        // Refresh app state
        await _refreshAppState();
      } finally {
        _isPaused = false;
        _isResuming = false;
      }
    }
  }

  Future<void> _saveAppState() async {
    // Override this method in implementing classes to save state
  }

  Future<void> _refreshAppState() async {
    // Override this method in implementing classes to refresh state
  }

  Future<void> _refreshSessionIfNeeded() async {
    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUser();

    // If session is invalid, handle accordingly
    if (!userProvider.isSessionValid) {
      await userProvider.logout();
      // Navigate to login page if needed
    }
  }
}
