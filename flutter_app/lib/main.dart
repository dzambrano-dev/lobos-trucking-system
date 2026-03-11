import 'package:flutter/material.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const LobosApp());
}

class LobosApp extends StatelessWidget {
  const LobosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lobos Trucking',

      // removes debug banner
      debugShowCheckedModeBanner: false,

      // app theme
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),

      // first page that loads
      home: const Dashboard(),
    );
  }
}
