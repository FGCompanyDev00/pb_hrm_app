// lib/services/services_locator.dart

import 'package:get_it/get_it.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/offline_service.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  sl.registerSingleton<UserPreferences>(UserPreferences());
  sl.registerSingleton<OfflineService>(OfflineService());
}
