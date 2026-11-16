import 'package:fatoura/core/localization/app_localizations.dart';
import 'package:fatoura/core/widgets/app_logo.dart';
import 'package:fatoura/core/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestable(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      locale: const Locale('ar'),
      home: child,
    );
  }

  group('AppLogo Widget Tests', () {
    testWidgets('renders AppLogo with default image without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const Scaffold(
            body: Center(
              child: AppLogo(size: 64),
            ),
          ),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 64.0);
      expect(image.height, 64.0);
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('renders AppLogo with app name in Light Mode', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const Scaffold(
            body: Center(
              child: AppLogo(
                size: 80,
                showAppName: true,
              ),
            ),
          ),
          themeMode: ThemeMode.light,
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('فاتورة'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('فاتورة'));
      expect(textWidget.style?.color, const Color(0xFF0F172A));
    });

    testWidgets('renders AppLogo with app name in Dark Mode', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const Scaffold(
            body: Center(
              child: AppLogo(
                size: 80,
                showAppName: true,
              ),
            ),
          ),
          themeMode: ThemeMode.dark,
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('فاتورة'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('فاتورة'));
      expect(textWidget.style?.color, const Color(0xFFFFFFFF));
    });

    testWidgets('renders custom app name and subtitle', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const Scaffold(
            body: Center(
              child: AppLogo(
                size: 80,
                showAppName: true,
                appName: 'Fatoura POS',
                subtitle: 'Offline First Accounting',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Fatoura POS'), findsOneWidget);
      expect(find.text('Offline First Accounting'), findsOneWidget);
    });
  });

  group('SplashScreen Widget Tests', () {
    testWidgets('renders SplashScreen with Light Mode background and text color', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const SplashScreen(showProgress: true),
          themeMode: ThemeMode.light,
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

      final textWidget = tester.widget<Text>(find.text('فاتورة'));
      expect(textWidget.style?.color, const Color(0xFF0F172A));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders SplashScreen with Dark Mode background and text color', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const SplashScreen(showProgress: true),
          themeMode: ThemeMode.dark,
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF0F172A));

      final textWidget = tester.widget<Text>(find.text('فاتورة'));
      expect(textWidget.style?.color, const Color(0xFFFFFFFF));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
