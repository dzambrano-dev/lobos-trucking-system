import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/dashboard.dart';

// 🔥 GLOBAL NAVIGATION KEY
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🔥 SAFE FIREBASE INIT
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(const LobosApp());
  } catch (e) {
    // 🔥 IF FIREBASE FAILS → STILL RUN APP (with error screen)
    runApp(LobosApp(startupError: e.toString()));
  }
}

class LobosApp extends StatelessWidget {
  final String? startupError;

  const LobosApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lobos Trucking',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      // ================= THEME =================
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.grey[100],

        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),

        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),

        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),

      // ================= DARK MODE =================
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),

      themeMode: ThemeMode.system,

      // ================= ENTRY =================
      home: startupError != null
          ? ErrorScreen(error: startupError!)
          : const AppRoot(),
    );
  }
}

// ================= ROOT =================
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 FUTURE AUTH SWITCH
    // if (user == null) return LoginPage();

    return const Dashboard();
  }
}

// ================= LOADING =================
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 60),
            SizedBox(height: 20),
            Text(
              "Lobos Trucking",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ================= ERROR SCREEN =================
class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 70, color: Colors.red),

              const SizedBox(height: 20),

              const Text(
                "Startup Failed",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await Firebase.initializeApp(
                      options: DefaultFirebaseOptions.currentPlatform,
                    );

                    navigatorKey.currentState!.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AppRoot()),
                      (route) => false,
                    );
                  } catch (e) {
                    // 🔥 Retry failed again → update UI
                    navigatorKey.currentState!.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ErrorScreen(error: e.toString()),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
