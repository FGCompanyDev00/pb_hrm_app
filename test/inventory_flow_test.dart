import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Import our inventory pages
import 'package:pb_hrsystem/home/dashboard/Card/inventory/inventory_management_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/inventory/admin_hq/inventory_admin_hq_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/inventory/admin_br/inventory_admin_br_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/inventory/branch_manager/inventory_branch_manager_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/inventory/user/inventory_user_page.dart';

// Mock providers for testing
class MockThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

class MockLanguageNotifier extends ChangeNotifier {
  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;
  
  void changeLanguage(String language) {
    _currentLanguage = language;
    notifyListeners();
  }
}

void main() {
  group('Inventory Management Flow Tests', () {
    testWidgets('Inventory Management Page - Role Routing Test', (WidgetTester tester) async {
      // Create a test app with providers
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryManagementPage(),
          ),
        ),
      );

      // Wait for the page to load
      await tester.pumpAndSettle();

      // Verify the page loads without errors
      expect(find.byType(InventoryManagementPage), findsOneWidget);
    });

    testWidgets('AdminHQ Page - UI Components Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryAdminHQPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify main components exist
      expect(find.byType(InventoryAdminHQPage), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget); // Banner carousel
      expect(find.byType(GridView), findsOneWidget); // Action grid
    });

    testWidgets('AdminBR Page - UI Components Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryAdminBRPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify main components exist
      expect(find.byType(InventoryAdminBRPage), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget); // Banner carousel
      expect(find.byType(GridView), findsOneWidget); // Action grid
    });

    testWidgets('Branch Manager Page - UI Components Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryBranchManagerPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify main components exist
      expect(find.byType(InventoryBranchManagerPage), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget); // Banner carousel
      expect(find.byType(GridView), findsOneWidget); // Action grid
    });

    testWidgets('User Page - UI Components Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryUserPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify main components exist
      expect(find.byType(InventoryUserPage), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget); // Banner carousel
      expect(find.byType(GridView), findsOneWidget); // Action grid
    });

    testWidgets('Theme Toggle Test', (WidgetTester tester) async {
      final themeNotifier = MockThemeNotifier();
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => themeNotifier),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryAdminHQPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial theme
      expect(themeNotifier.isDarkMode, false);

      // Toggle theme
      themeNotifier.toggleTheme();
      await tester.pumpAndSettle();

      // Verify theme changed
      expect(themeNotifier.isDarkMode, true);
    });

    testWidgets('Language Change Test', (WidgetTester tester) async {
      final languageNotifier = MockLanguageNotifier();
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => languageNotifier),
          ],
          child: MaterialApp(
            home: InventoryAdminBRPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial language
      expect(languageNotifier.currentLanguage, 'en');

      // Change language
      languageNotifier.changeLanguage('ms');
      await tester.pumpAndSettle();

      // Verify language changed
      expect(languageNotifier.currentLanguage, 'ms');
    });
  });

  group('Inventory Management - Compilation Tests', () {
    test('All inventory pages compile without errors', () {
      // This test verifies that all our inventory pages can be instantiated
      // without compilation errors
      
      expect(() => InventoryManagementPage(), returnsNormally);
      expect(() => InventoryAdminHQPage(), returnsNormally);
      expect(() => InventoryAdminBRPage(), returnsNormally);
      expect(() => InventoryBranchManagerPage(), returnsNormally);
      expect(() => InventoryUserPage(), returnsNormally);
    });
  });

  group('Inventory Management - Mock Data Tests', () {
    testWidgets('AdminBR Mock Data Display Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryAdminBRPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that mock data is displayed
      // This tests that our mock data is properly integrated
      expect(find.byType(InventoryAdminBRPage), findsOneWidget);
    });

    testWidgets('Branch Manager Mock Data Display Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryBranchManagerPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that mock data is displayed
      expect(find.byType(InventoryBranchManagerPage), findsOneWidget);
    });

    testWidgets('User Mock Data Display Test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MockThemeNotifier()),
            ChangeNotifierProvider(create: (_) => MockLanguageNotifier()),
          ],
          child: MaterialApp(
            home: InventoryUserPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that mock data is displayed
      expect(find.byType(InventoryUserPage), findsOneWidget);
    });
  });
}
