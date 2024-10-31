import 'package:flutter/material.dart';

/// Used to get global context
class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  //static BuildContext? get ctx => router.routerDelegate.navigatorKey.currentContext;
  static BuildContext? get ctx => navigatorKey.currentState?.context;

  static isThereCurrentDialogShowing(BuildContext context) => ModalRoute.of(context)?.isCurrent != true;
}
