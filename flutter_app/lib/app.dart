import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/auth/auth_gate.dart';

class LobosApp extends StatelessWidget {
  const LobosApp({super.key, this.startupError});

  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF174A7E),
    );

    return MaterialApp(
      title: 'Lobos Trucking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          clipBehavior: Clip.antiAlias,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: startupError == null
          ? const AuthGate()
          : StartupErrorPage(error: startupError!),
    );
  }
}

class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Lobos Trucking could not start',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Check the internet connection and Firebase configuration, '
                    'then reopen the app.',
                    textAlign: TextAlign.center,
                  ),
                  // Full exception text is useful during development, but it
                  // can reveal configuration details in a production build.
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
