import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _activateAppCheckWhenConfigured();
  } catch (error) {
    startupError = error;
  }

  runApp(LobosApp(startupError: startupError));
}

Future<void> _activateAppCheckWhenConfigured() async {
  const enabled = bool.fromEnvironment('ENABLE_APP_CHECK');
  if (!enabled) return;

  const webSiteKey = String.fromEnvironment('APP_CHECK_WEB_KEY');
  if (kIsWeb && webSiteKey.isEmpty && kReleaseMode) {
    throw StateError(
      'APP_CHECK_WEB_KEY is required when App Check is enabled for web.',
    );
  }

  await FirebaseAppCheck.instance.activate(
    providerWeb: kDebugMode
        ? WebDebugProvider()
        : ReCaptchaV3Provider(webSiteKey),
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );
}
