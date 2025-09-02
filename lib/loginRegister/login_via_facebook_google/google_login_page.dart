// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:luckygo_pemandu/auth_gate.dart';
// import 'package:luckygo_pemandu/global.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// // ★ Prefix the plugin to avoid any class name clashes.
// import 'package:google_sign_in/google_sign_in.dart' as gsi;

// class LoginViaGoogle extends StatefulWidget {
//   const LoginViaGoogle({super.key});

//   @override
//   State<LoginViaGoogle> createState() => _LoginViaGoogleState();
// }

// class _LoginViaGoogleState extends State<LoginViaGoogle> {
//   late SharedPreferences _prefs;

//   String? country, stateName, language, phone;
//   bool isReady = false;
//   bool signingIn = false;

//   // Only phone is a text field; others use dropdowns in the dialog
//   final TextEditingController phoneCtrl = TextEditingController();

//   // Selected (outer) values
//   String? selectedCountry;
//   String? selectedState;
//   String? selectedLanguage;

//   final List<String> _countries = const ["Malaysia", "Indonesia", "Timor-Leste"];

//   final Map<String, List<String>> _statesByCountry = const {
//     "Malaysia": [
//       "Johor","Kedah","Kelantan","Melaka","Negeri Sembilan","Pahang",
//       "Penang","Perak","Perlis","Sabah","Sarawak","Selangor",
//       "Terengganu","Kuala Lumpur","Labuan","Putrajaya",
//     ],
//     "Indonesia": [
//       "Aceh","Bali","Banten","Bengkulu","Central Java","Central Kalimantan",
//       "Central Sulawesi","East Java","East Kalimantan","East Nusa Tenggara",
//       "Gorontalo","Jakarta","Jambi","Lampung","Maluku","North Kalimantan",
//       "North Maluku","North Sulawesi","North Sumatra","Papua","Riau",
//       "Riau Islands","Southeast Sulawesi","South Kalimantan","South Sulawesi",
//       "South Sumatra","West Java","West Kalimantan","West Nusa Tenggara",
//       "West Papua","West Sulawesi","West Sumatra","Yogyakarta",
//     ],
//     "Timor-Leste": [
//       "Aileu","Ainaro","Baucau","Bobonaro","Cova Lima","Dili","Ermera",
//       "Lautem","Liquiçá","Manatuto","Manufahi","Viqueque",
//     ],
//   };

//   final Map<String, List<String>> _langsByCountry = const {
//     "Malaysia": ["English", "Malay", "Chinese"],
//     "Indonesia": ["Indonesian", "English"],
//     "Timor-Leste": ["Tetun", "Portuguese", "English"],
//   };

//   @override
//   void initState() {
//     super.initState();
//     _initPrefs();
//   }

//   @override
//   void dispose() {
//     phoneCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _initPrefs() async {
//     try {
//       _prefs = await SharedPreferences.getInstance();

//       // Raw reads (trim after reading)
//       final rawCountry   = _prefs.getString('country');
//       final rawState     = _prefs.getString('state');
//       final rawLanguage  = _prefs.getString('language');
//       final rawPhone     = _prefs.getString('phone') ?? _prefs.getString('driverPhone');

//       // Normalize/trim
//       country   = (rawCountry  ?? '').trim();
//       stateName = (rawState    ?? '').trim();
//       language  = (rawLanguage ?? '').trim();
//       phone     = (rawPhone    ?? '').trim();

//       // 🔎 Print exactly what we loaded
//       print('[PREFS][LOAD] keys=${_prefs.getKeys()}');
//       print('[PREFS][LOAD] country="$country"  state="$stateName"  language="$language"  phone="$phone"');

//       // Optional: preload into Gv
//       if ((phone ?? '').isNotEmpty) {
//         Gv.loggedUser = phone!.trim();
//       }

//       // Preselect dropdowns
//       selectedCountry  = country!.isNotEmpty   ? country   : null;
//       selectedState    = stateName!.isNotEmpty ? stateName : null;
//       selectedLanguage = language!.isNotEmpty  ? language  : null;
//       if ((phone ?? '').isNotEmpty) phoneCtrl.text = phone!;

//       final missing = [country, stateName, language, phone]
//           .any((v) => (v ?? '').trim().isEmpty);
//       if (missing) {
//         WidgetsBinding.instance.addPostFrameCallback((_) => _showMetadataDialog());
//       } else {
//         if (!mounted) return;
//         setState(() => isReady = true);
//       }
//     } catch (e, st) {
//       print('[PREFS][LOAD][ERR] $e');
//       print(st);
//       WidgetsBinding.instance.addPostFrameCallback((_) => _showMetadataDialog());
//     }
//   }

//   void _showMetadataDialog() {
//     String? dCountry = selectedCountry;
//     String? dState   = selectedState;
//     String? dLang    = selectedLanguage;
//     final TextEditingController dPhoneCtrl =
//         TextEditingController(text: phoneCtrl.text);

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogCtx) => StatefulBuilder(
//         builder: (dialogCtx, setDialogState) {
//           bool saving = false;

//           final states = dCountry == null ? const <String>[] : (_statesByCountry[dCountry] ?? const <String>[]);
//           final langs  = dCountry == null ? const <String>[] : (_langsByCountry[dCountry] ?? const <String>[]);

//           Future<void> onSave() async {
//             if (saving) return;

//             final c = (dCountry ?? '').trim();
//             final s = (dState   ?? '').trim();
//             final l = (dLang    ?? '').trim();
//             final p = dPhoneCtrl.text.trim();

//             // Print what we are about to save
//             print('[PREFS][SAVE][INPUT] country="$c"  state="$s"  language="$l"  phone="$p"');

//             if ([c, s, l, p].any((e) => e.isEmpty)) {
//               if (mounted) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Please fill all fields')),
//                 );
//               }
//               return;
//             }

//             setDialogState(() => saving = true);
//             try {
//               // Save individually + print confirmations
//               await _prefs.setString('country', c);

//               await _prefs.setString('state', s);

//               await _prefs.setString('language', l);

//               await _prefs.setString('phone', p);
//               await _prefs.setString('driverPhone', p);

//               // Read back immediately to verify what is in local storage
//               final rbCountry  = (_prefs.getString('country')  ?? '').trim();
//               final rbState    = (_prefs.getString('state')    ?? '').trim();
//               final rbLanguage = (_prefs.getString('language') ?? '').trim();
//               final rbPhone    = (_prefs.getString('phone')    ?? '').trim();

//               print('[PREFS][AFTER_SAVE_READBACK] '
//                     'country="$rbCountry"  state="$rbState"  language="$rbLanguage"  phone="$rbPhone"🎈🎈🎈🎈🎈🎈🎈\n'*10);

//               if (!mounted) return;
//               setState(() {
//                 country = c; stateName = s; language = l; phone = p;
//                 selectedCountry = c; selectedState = s; selectedLanguage = l;
//                 phoneCtrl.text = p; isReady = true;
//               });

//               print('[LOGIN_PAGE] saved prefs -> /$c/$s/driver_account/$p lang=$l');
//               if (Navigator.of(dialogCtx).canPop()) Navigator.of(dialogCtx).pop();
//             } catch (e, st) {
//               print('[PREFS][SAVE][ERR] $e');
//               print(st);
//               if (mounted) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Save error: $e')),
//                 );
//               }
//             } finally {
//               setDialogState(() => saving = false);
//             }
//           }

//           return AlertDialog(
//             title: const Text('Complete Your Info'),
//             content: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   DropdownButtonFormField<String>(
//                     value: dCountry,
//                     hint: const Text('Select country'),
//                     items: _countries
//                         .map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
//                         .toList(),
//                     onChanged: (v) {
//                       setDialogState(() {
//                         dCountry = v; dState = null; dLang = null;
//                       });
//                       print('[DIALOG][SELECT] country="$v"');
//                     },
//                   ),
//                   const SizedBox(height: 12),
//                   DropdownButtonFormField<String>(
//                     value: dState,
//                     hint: const Text('Select state'),
//                     items: states
//                         .map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
//                         .toList(),
//                     onChanged: (v) {
//                       setDialogState(() => dState = v);
//                       print('[DIALOG][SELECT] state="$v"');
//                     },
//                   ),
//                   const SizedBox(height: 12),
//                   DropdownButtonFormField<String>(
//                     value: dLang,
//                     hint: const Text('Select language'),
//                     items: langs
//                         .map<DropdownMenuItem<String>>((l) => DropdownMenuItem<String>(value: l, child: Text(l)))
//                         .toList(),
//                     onChanged: (v) {
//                       setDialogState(() => dLang = v);
//                       print('[DIALOG][SELECT] language="$v"');
//                     },
//                   ),
//                   const SizedBox(height: 12),
//                   TextField(
//                     controller: dPhoneCtrl,
//                     decoration: const InputDecoration(
//                       labelText: 'Phone (doc id)',
//                       border: OutlineInputBorder(),
//                     ),
//                     keyboardType: TextInputType.phone,
//                     onChanged: (v) => print('[DIALOG][SELECT] phone="$v"'),
//                   ),
//                 ],
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: onSave,
//                 child: saving
//                     ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
//                     : const Text('Save'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   /// Google Sign-In:
//   /// - Web: signInWithPopup + LOCAL persistence (Auth saves email automatically)
//   /// - Android/iOS: native google_sign_in (no browser)
//   /// After sign-in, we set Auth.displayName = phone (so you can fetch phone via Auth).
//   Future<void> handleGoogleSignIn() async {
//     if (signingIn) return;
//     if (!mounted) return;

//     final c = (country ?? '').trim();
//     final s = (stateName ?? '').trim();
//     final l = (language ?? '').trim();
//     final p = (phone ?? '').trim();
//     print('[GSIGN][CHECK] about_to_signin country="$c" state="$s" language="$l" phone="$p"');
//     if ([c, s, l, p].any((e) => e.isEmpty)) { _showMetadataDialog(); return; }

//     setState(() => signingIn = true);
//     print('[GSIGN] start kIsWeb=$kIsWeb path=/$c/$s/driver_account/$p lang=$l');

//     try {
//       UserCredential cred;

//       if (kIsWeb) {
//         await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
//         final provider = GoogleAuthProvider()..addScope('email');
//         cred = await FirebaseAuth.instance.signInWithPopup(provider);
//         print('[GSIGN] web popup ok uid=${cred.user?.uid} email=${cred.user?.email}');
//       } else {
//         print('[GSIGN] mobile via google_sign_in (native)');
//         final gsi.GoogleSignIn googleSignIn = gsi.GoogleSignIn(scopes: const ['email']);

//         // Clean any stale session
//         try { await googleSignIn.signOut(); } catch (_) {}
//         try { await FirebaseAuth.instance.signOut(); } catch (_) {}

//         final gsi.GoogleSignInAccount? gUser = await googleSignIn.signIn();
//         if (gUser == null) {
//           print('[GSIGN] user cancelled');
//           setState(() => signingIn = false);
//           return;
//         }

//         final gsi.GoogleSignInAuthentication gAuth = await gUser.authentication;
//         final oauth = GoogleAuthProvider.credential(
//           accessToken: gAuth.accessToken,
//           idToken: gAuth.idToken,
//         );
//         cred = await FirebaseAuth.instance.signInWithCredential(oauth);
//         print('[GSIGN] mobile native ok uid=${cred.user?.uid} email=${cred.user?.email}');
//       }

//       final user = cred.user;
//       if (user == null) {
//         throw FirebaseAuthException(code: 'user-null', message: 'Google sign-in returned null user');
//       }

//       // 🔹 Put the phone into Authentication by using displayName as the "username"
//       final originalName = user.displayName ?? '';
//       if ((user.displayName ?? '') != p) {
//         try {
//           await user.updateDisplayName(p);  // save phone as Auth "name"
//           await user.reload();
//           print('[GSIGN] Auth.displayName set to phone="$p" (was "$originalName")');
//         } catch (e) {
//           print('[GSIGN][WARN] updateDisplayName failed: $e');
//         }
//       }

//       // Ensure our app-global loggedUser is phone
//       Gv.loggedUser = p;

//       // Firestore write: /{country}/{state}/driver_account/{phone}
//       final ref = FirebaseFirestore.instance
//           .collection(c)
//           .doc(s)
//           .collection('driver_account')
//           .doc(p);

//       final doc = await ref.get();
//       if (!doc.exists) {
//         print('[GSIGN] writing Firestore doc…');
//         await ref.set({
//           'account_balance': 0,
//           'photoUrl': user.photoURL ?? '',
//           'country': c,
//           'createdAt': FieldValue.serverTimestamp(),
//           'disclosureAccepted': false,
//           'email': user.email ?? '',
//           'form2_completed': false,
//           'language': l,
//           'name': originalName,  
//           'originalDisplayName': originalName,
//           'phone': p,
//           'registration_approved': false,
//           'reg_selfie_image_url': '',
//           'state': s,
//           'uid': user.uid,
//         });
//         print('[GSIGN] Firestore write success');
//       } else {
//         print('[GSIGN] Firestore doc exists → skip write');
//         await ref.update({
//           'phone': p,
//           'name': originalName,
//           'language': l,
//           'country': c,
//           'state': s,
//         });
//       }

//       // Persist locally too (future boots)
//       await _prefs.setString('country', c);
//       await _prefs.setString('state', s);
//       await _prefs.setString('language', l);
//       await _prefs.setString('phone', p);
//       await _prefs.setString('driverPhone', p);

//       // Verify what is finally in prefs after sign-in
//       final rbCountry  = (_prefs.getString('country')  ?? '').trim();
//       final rbState    = (_prefs.getString('state')    ?? '').trim();
//       final rbLanguage = (_prefs.getString('language') ?? '').trim();
//       final rbPhone    = (_prefs.getString('phone')    ?? '').trim();
//       print('[PREFS][AFTER_SAVE_READBACK][POST_GSIGN] '
//             'country="$rbCountry" state="$rbState" language="$rbLanguage" phone="$rbPhone"');

//       // ✅ Navigate back to the normal app flow (AuthGate → LandingPage)
//       if (!mounted) return;
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => const AuthGate()),
//         (route) => false,
//       );


//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-in complete')));
//     } on FirebaseAuthException catch (e, st) {
//       print('[GSIGN][AUTH_ERR] code=${e.code} message=${e.message}');
//       print(st);
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Auth error: ${e.message ?? e.code}')),
//         );
//       }
//     } catch (e, st) {
//       print('[GSIGN][ERR] $e');
//       print(st);
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: $e')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => signingIn = false);
//       print('[GSIGN] done');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Login')),
//       body: Center(
//         child: isReady
//             ? ElevatedButton.icon(
//                 icon: const Icon(Icons.login),
//                 label: Text(signingIn ? 'Signing in…' : 'Continue with Google'),
//                 onPressed: signingIn ? null : handleGoogleSignIn,
//               )
//             : const CircularProgressIndicator(),
//       ),
//     );
//   }
// }
