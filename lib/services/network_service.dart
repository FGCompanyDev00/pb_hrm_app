import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final _connectivity = Connectivity();
  final _internetChecker = InternetConnectionChecker();

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  bool _isInitialized = false;
  Timer? _pollingTimer;
  bool _lastKnownState = true;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initial connectivity check
    _checkConnectivity();

    // Listen to platform connectivity changes
    _connectivity.onConnectivityChanged.listen((result) async {
      // On iOS, we need to do an additional internet check
      if (Platform.isIOS) {
        if (result == ConnectivityResult.none) {
          _updateConnectivityState(false);
        } else {
          // Verify actual internet connectivity
          final hasInternet = await _internetChecker.hasConnection;
          _updateConnectivityState(hasInternet);
        }
      } else {
        _updateConnectivityState(result != ConnectivityResult.none);
      }
    });

    // Start polling on iOS (helps with more reliable connectivity detection)
    if (Platform.isIOS) {
      _startPolling();
    }

    _isInitialized = true;
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _updateConnectivityState(false);
      } else {
        // Always verify internet connectivity
        final hasInternet = await _internetChecker.hasConnection;
        _updateConnectivityState(hasInternet);
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _updateConnectivityState(false);
    }
  }

  void _updateConnectivityState(bool isConnected) {
    if (_lastKnownState != isConnected) {
      _lastKnownState = isConnected;
      _connectivityController.add(isConnected);
    }
  }

  Future<bool> isConnected() async {
    if (Platform.isIOS) {
      // On iOS, we do a full internet check
      return _internetChecker.hasConnection;
    } else {
      // On Android, we can rely more on the connectivity result
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _connectivityController.close();
  }
}
