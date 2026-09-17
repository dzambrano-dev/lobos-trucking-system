import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? error;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    error =
        'Unable to connect to the company workspace. Check your connection and restart the app.';
  }
  runApp(LobosApp(startupError: error));
}

ThemeData lobosTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF23796B),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F6F3),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF5F6F3),
    centerTitle: false,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE3E8E3)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: Color(0xFFF5F6F3),
  ),
);

class LobosApp extends StatelessWidget {
  const LobosApp({super.key, this.startupError, this.home});
  final String? startupError;
  final Widget? home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lobos Trucking',
    debugShowCheckedModeBanner: false,
    theme: lobosTheme(),
    home:
        home ??
        (startupError == null
            ? const AuthGate()
            : Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(startupError!, textAlign: TextAlign.center),
                  ),
                ),
              )),
  );
}
