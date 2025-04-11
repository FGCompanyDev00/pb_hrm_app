// lib/services/services_locator.dart

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  try {
    // Check if UserPreferences is already registered to avoid duplicate registration
    if (!sl.isRegistered<UserPreferences>()) {
      final prefs = await SharedPreferences.getInstance();

      // Register UserPreferences first with higher priority
      sl.registerLazySingleton<UserPreferences>(() => UserPreferences(prefs));
      debugPrint('UserPreferences service registered successfully');
    } else {
      debugPrint('UserPreferences already registered');
    }

    // Register other services if not already registered
    if (!sl.isRegistered<Connectivity>()) {
      sl.registerLazySingleton<Connectivity>(() => Connectivity());
      debugPrint('Connectivity service registered successfully');
    }

    if (!sl.isRegistered<OfflineProvider>()) {
      sl.registerLazySingleton<OfflineProvider>(() => OfflineProvider());
      debugPrint('OfflineProvider service registered successfully');
    }
  } catch (e) {
    debugPrint("Error during service locator setup: $e");

    // Attempt recovery if possible
    if (!sl.isRegistered<UserPreferences>()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        sl.registerLazySingleton<UserPreferences>(() => UserPreferences(prefs));
        debugPrint('UserPreferences service registered in recovery mode');
      } catch (recoveryError) {
        debugPrint(
            "Critical error: Failed to register UserPreferences even in recovery mode: $recoveryError");
      }
    }
  }
}
