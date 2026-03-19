import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LobosApp());
}

class LobosApp extends StatelessWidget {
  const LobosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lobos Trucking',
      debugShowCheckedModeBanner: false,

      // ================= THEME =================
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,

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
      ),

      // ================= APP ENTRY =================
      home: const FirebaseInitializer(),
    );
  }
}

class FirebaseInitializer extends StatelessWidget {
  const FirebaseInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),

      builder: (context, snapshot) {
        // ================= LOADING =================
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ================= ERROR =================
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                "Firebase failed to initialize.\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // ================= SUCCESS =================
        return const Dashboard();
      },
    );
  }
}
