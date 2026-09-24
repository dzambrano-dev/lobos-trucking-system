import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dashboard.dart';
import '../models/app_user.dart';
import '../services/user_repository.dart';
import 'driver/driver_loads_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!snapshot.hasData) return const SignInPage();
      final user = snapshot.data!;
      return StreamBuilder<AppUser?>(
        stream: UserRepository().watchUser(user.uid),
        builder: (context, member) {
          if (member.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final profile = member.data;
          if (!member.hasError &&
              profile != null &&
              profile.active &&
              profile.isAdmin) {
            return _session(
              profile,
              Dashboard(
                key: ValueKey(user.uid),
                user: profile,
                onSignOut: () => FirebaseAuth.instance.signOut(),
              ),
            );
          }
          if (!member.hasError &&
              profile != null &&
              profile.active &&
              profile.permissions.updateAssignedLoads) {
            return _session(
              profile,
              DriverLoadsPage(key: ValueKey(user.uid), user: profile),
            );
          }
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      member.hasError
                          ? 'Unable to verify workspace access. Check your connection or contact the owner.'
                          : 'Your account has not been enabled for this workspace. Ask the owner to activate your staff access.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _session(AppUser user, Widget home) => Navigator(
  key: ValueKey('${user.uid}:${user.permissions.toMap()}'),
  onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => home),
);

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => error = e.code == 'network-request-failed'
              ? 'Check your internet connection and try again.'
              : 'Could not sign in. Check your email and password, or contact the owner.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Sign-in is unavailable. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.local_shipping,
                  size: 52,
                  color: Color(0xFF23796B),
                ),
                const SizedBox(height: 20),
                Text(
                  'Lobos Trucking',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to your company workspace',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Enter your email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  enabled: !busy,
                  obscureText: hidden,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) {
                    if (!busy) signIn();
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your password' : null,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : signIn,
                  child: Text(busy ? 'Signing in…' : 'Sign in'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Need an account or a password reset? Contact your company administrator.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
