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
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Dashboard(),
    );
  }
}
