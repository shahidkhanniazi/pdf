import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'data/repository.dart';
import 'screens/splash_screen.dart';
import 'services/ads.dart';
import 'services/notifications.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  try {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ur');
  } catch (_) {
    // Dates fall back to English formatting.
  }
  await NotificationService.instance.init();
  // Ads load in the background; the app never waits for them.
  AdService.instance.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(prefs, Repository()),
      child: const SomethingHistoricApp(),
    ),
  );
}

class SomethingHistoricApp extends StatelessWidget {
  const SomethingHistoricApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final urdu = app.isUrdu;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        themeMode: app.themeMode,
        theme: buildTheme(Brightness.light, urdu: urdu),
        darkTheme: buildTheme(Brightness.dark, urdu: urdu),
        locale: Locale(app.lang),
        supportedLocales: const [Locale('en'), Locale('ur')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
