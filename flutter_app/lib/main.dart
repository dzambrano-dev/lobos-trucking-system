import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Correct import based on your structure
import 'screens/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const LobosApp());
}

class LobosApp extends StatelessWidget {
  const LobosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lobos Trucking',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],

        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),

      home: const Dashboard(),
    );
  }
}
