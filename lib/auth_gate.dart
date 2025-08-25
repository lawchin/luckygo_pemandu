import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'global.dart';
import 'loginRegister/login_page.dart';
import 'landing page/landing_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static String? _lastUid; // prevent repeated writes to Gv on rebuilds

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null) {
          // Not signed in -> clear globals, show Login
          _lastUid = null;
          Gv.loggedUser = '';
          Gv.userName = '';
          return const LoginPage();
        }

        // Only update globals if the auth user actually changed
        if (_lastUid != user.uid) {
          _lastUid = user.uid;

          final email = user.email ?? '';
          Gv.loggedUser = email.endsWith('@driver.com')
              ? email.replaceAll('@driver.com', '')
              : email;
          Gv.userName = (user.displayName ?? '').trim();
 
        }

        return const LandingPage();
      },
    );
  }
}
