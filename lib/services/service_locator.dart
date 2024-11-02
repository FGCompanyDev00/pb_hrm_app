import 'package:get_it/get_it.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> startup() async {
  final prefs = await SharedPreferences.getInstance();

  sl.registerLazySingleton<UserPreferences>(() => UserPreferences(prefs));
}
