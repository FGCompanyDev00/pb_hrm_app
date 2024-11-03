// lib/services/services_locator.dart

import 'package:get_it/get_it.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  final prefs = await SharedPreferences.getInstance();

  sl.registerSingleton<UserPreferences>(UserPreferences(prefs));
  sl.registerSingleton<OfflineService>(OfflineService());
}
