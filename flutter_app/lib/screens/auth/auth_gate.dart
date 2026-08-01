import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/user_repository.dart';
import '../home/home_router.dart';
import 'access_pending_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPage(message: 'Checking your session…');
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) return const LoginPage();

        return StreamBuilder<AppUser?>(
          stream: UserRepository().watchUser(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingPage(message: 'Loading your access…');
            }
            if (profileSnapshot.hasError) {
              return const AccessPendingPage(
                title: 'Unable to verify access',
                message: 'Check the connection and try signing in again.',
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return const AccessPendingPage(
                title: 'Account setup required',
                message:
                    'Your login works, but an administrator still needs to '
                    'create your Lobos Trucking user profile.',
              );
            }
            if (!profile.active) {
              return const AccessPendingPage(
                title: 'Account disabled',
                message:
                    'Ask an administrator to reactivate your Lobos Trucking '
                    'access.',
              );
            }

            return HomeRouter(user: profile);
          },
        );
      },
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_rounded, size: 56),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
