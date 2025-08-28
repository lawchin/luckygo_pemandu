import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'global.dart';
import 'loginRegister/login_page.dart';
import 'landing page/landing_page.dart';

// ⬇️ Geofencing wrapper (starts after login, using Gv.negara/Gv.negeri)
import 'package:luckygo_pemandu/geo_fencing/geofencing_bootstrap_page.dart';

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

        // Safety: ensure region is present (loaded earlier in main bootstrap)
        final negara = (Gv.negara).trim();
        final negeri = (Gv.negeri).trim();

        if (negara.isEmpty || negeri.isEmpty) {
          // If region isn't ready yet, keep UI responsive but avoid starting geofencing.
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Loading region settings…',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ✅ Logged in → start geofencing for this region only
        return GeofencingBootstrapPage(
          negara: negara,  // e.g., 'Malaysia' / 'Timor-Leste' / 'Indonesia'
          negeri: negeri,  // e.g., 'Sabah' / 'Dili' / etc.
          builder: (ctx, blocked) {
            // Your normal post-login app
            return const LandingPage();
          },
        );
      },
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// import 'global.dart';
// import 'loginRegister/login_page.dart';
// import 'landing page/landing_page.dart';

// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});

//   static String? _lastUid; // prevent repeated writes to Gv on rebuilds

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snap) {
//         if (snap.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }

//         final user = snap.data;
//         if (user == null) {
//           // Not signed in -> clear globals, show Login
//           _lastUid = null;
//           Gv.loggedUser = '';
//           Gv.userName = '';
//           return const LoginPage();
//         }

//         // Only update globals if the auth user actually changed
//         if (_lastUid != user.uid) {
//           _lastUid = user.uid;

//           final email = user.email ?? '';
//           Gv.loggedUser = email.endsWith('@driver.com')
//               ? email.replaceAll('@driver.com', '')
//               : email;
//           Gv.userName = (user.displayName ?? '').trim();
 
//         }

//         return const LandingPage();
//       },
//     );
//   }
// }
