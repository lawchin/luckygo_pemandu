import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';

import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart';
import 'package:luckygo_pemandu/loginRegister/fill_form.dart';
import 'package:luckygo_pemandu/loginRegister/register_page.dart';
import 'package:luckygo_pemandu/loginRegister/register_with_otp.dart';
import 'package:luckygo_pemandu/main.dart';
import 'package:luckygo_pemandu/translate_bahasa.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _negara;
  String? _negeri;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
// bool _didFetchLocal = false;
// String? _appliedLangCode;

  @override
  void initState() {
    super.initState();
    _fetchLocalData();
  }

  Future<void> _fetchLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final country  = prefs.getString('country');
    final state    = prefs.getString('state');
    final area     = prefs.getString('area');
    final language = prefs.getString('language');

    if (country != null && state != null && area != null && language != null) {
      Gv.negara  = country;
      Gv.negeri  = state;
      Gv.kawasan = area;
      Gv.bahasa  = language;

      if (!mounted) return;
      setState(() {
        _negara = country;
        _negeri = state;
      });

      // Apply locale AFTER this frame, only if different from current locale
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final desired = localeFromLanguageName(Gv.bahasa);
        final currentCode = Localizations.maybeLocaleOf(context)?.languageCode;
        final desiredCode = desired?.languageCode;

        if (desired != null && desiredCode != currentCode) {
          MyApp.setLocale(context, desired);
        } else {
        }
      });

    } else {
      print('⚠ No local region data found. Showing “Before you continue” dialog.');

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Before you continue"),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("We don’t have your Country, State, Area, and Language yet."),
                SizedBox(height: 8),
                Text(
                  "If this is your first time, please Register a new account.\n"
                  "If you already have an account, Fill the form so we can locate your data.",
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                  );
                },
                child: const Text('Register New Account'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _openFillFormAndApply();
                },
                child: const Text('Fill Form'),
              ),
            ],
          ),
        );
      });
    }
  }

  Future<void> _openFillFormAndApply() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FillFormPopup(),
    );

    if (result != null && mounted) {
      final country  = result['country']  as String?;
      final state    = result['state']    as String?;
      final area     = result['area']     as String?;
      final language = result['language'] as String?;

      if (country != null && state != null && area != null && language != null) {
        Gv.negara  = country;
        Gv.negeri  = state;
        Gv.kawasan = area;
        Gv.bahasa  = language;

        setState(() {
          _negara = country;
          _negeri = state;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('country', country);
        await prefs.setString('state', state);
        await prefs.setString('area', area);
        await prefs.setString('language', language);
      }
    }
  }

  Future<void> _showError(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Build an email to auth with. If user typed a full email, use it.
  /// Otherwise, treat input as username/phone and append @driver.com
  String _toAuthEmail(String input) {
    final raw = input.trim();
    return raw.contains('@') ? raw : '$raw@driver.com';
  }

  /// Get a device identifier (without SharedPreferences).
  Future<String> _getDeviceId() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final id = a.id; // or a.androidId if your plugin version supports it
        if (id != null && id.isNotEmpty) return id;
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        final id = i.identifierForVendor;
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (_) {}
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    return '${Platform.operatingSystem}-$uid';
  }

  /// Before signing in, check if another device holds the session for this email.
  /// If yes, prompt the user to Continue Here (overwrite) or Cancel.
  Future<bool> _confirmSingleSession(String authEmail) async {
    if (Gv.negara.isEmpty || Gv.negeri.isEmpty) {
      await _showError('Region Required', 'Please set your Country and State first.');
      return false;
    }

    final ref = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('login_sessions')
        .doc(authEmail);

    try {
      final deviceId = await _getDeviceId();
      final snap = await ref.get();

      if (!snap.exists) return true; // No session → proceed

      final data = snap.data();
      final existing = data?['device_id'] as String?;
      if (existing == null || existing.isEmpty || existing == deviceId) {
        return true; // Free or already this device
      }

      // Show dialog: Continue here or Cancel
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Already Logged In'),
          content: const Text(
            'This account is currently logged in on another device.\n'
            'Do you want to log out the other device and continue here?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue Here'),
            ),
          ],
        ),
      );

      return proceed == true;
    } catch (e) {
      // If check fails, let login proceed (or you can block and show error)
      return true;
    }
  }

  /// Save/merge a login session using the *email* as the doc id.
  Future<void> _saveLoginSession({required String email}) async {
    if (Gv.negara.isEmpty || Gv.negeri.isEmpty) return;
    if (email.isEmpty) return;

    final deviceId = await _getDeviceId();

    final ref = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('login_sessions')
        .doc(email); // email as doc id

    await ref.set({
      'email': email,
      'device_id': deviceId,
      'uid': FirebaseAuth.instance.currentUser?.uid,
      'platform': Platform.operatingSystem,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Auth + Firestore verification with clear error mapping.
  Future<String> _loginAndAssertDriverAccount() async {
    final rawInput = _emailController.text.trim();
    final password = _passwordController.text;

    final negara = Gv.negara;
    final negeri = Gv.negeri;
    if (negara.isEmpty || negeri.isEmpty) {
      throw ('REGION_MISSING|Please set your Country and State first. Tap the globe icon to fill the form.');
    }
    if (rawInput.isEmpty || password.isEmpty) {
      throw ('INPUT_MISSING|Please enter your username/email and password.');
    }

    final String authEmail = _toAuthEmail(rawInput);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw ('AUTH|That email looks invalid. If you use a username, just type the username—we’ll add @driver.com.');
        case 'user-not-found':
          throw ('AUTH|No account found for these credentials.');
        case 'wrong-password':
          throw ('AUTH|Wrong password. Please try again.');
        case 'network-request-failed':
          throw ('AUTH|Network error. Check your connection and try again.');
        case 'too-many-requests':
          throw ('AUTH|Too many attempts. Please wait a moment and try again.');
        default:
          throw ('AUTH|Login failed: ${e.code}');
      }
    } catch (e) {
      throw ('AUTH|Login failed. ${e.toString()}');
    }

    // Update globals from the signed-in user
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      final email = current.email ?? authEmail;
      final username = email.endsWith('@driver.com')
          ? email.replaceAll('@driver.com', '')
          : email;
      Gv.loggedUser = username;
      Gv.userName = current.displayName ?? Gv.userName;
    }

    // Verify the driver document exists in the chosen region
    // try {
    //   // If your Firestore driver doc IDs are FULL EMAILS, change `docId` to `authEmail`.
    //   final String docId = rawInput; // or authEmail if your DB uses emails as IDs
    //   final snap = await FirebaseFirestore.instance
    //       .collection(negara)
    //       .doc(negeri)
    //       .collection('driver_account')
    //       .doc(docId)
    //       .get();

    //   if (!snap.exists) {
    //     throw ('DOC|Driver account not found in $negara / $negeri. Make sure you picked the same region you registered in.');
    //   }
    // } catch (e) {
    //   if (e is String) rethrow;
    //   throw ('DOC|Unable to verify driver account. ${e.toString()}');
    // }

try {
  final String docId = rawInput; // or authEmail if your DB uses emails as IDs
  final snap = await FirebaseFirestore.instance
      .collection(negara)
      .doc(negeri)
      .collection('driver_account')
      .doc(docId)
      .get();

  if (!snap.exists) {
    throw ('DOC|Driver account not found in $negara / $negeri. Make sure you picked the same region you registered in.');
  }

  // ✅ If group_capability exists, update global
  final data = snap.data();
  if (data != null && data.containsKey('group_capability')) {
    Gv.groupCapability = data['group_capability'] ?? 3; // default to 3 if null
  }

} catch (e) {
  if (e is String) rethrow;
  throw ('DOC|Unable to verify driver account. ${e.toString()}');
}

return FirebaseAuth.instance.currentUser?.email ?? authEmail;
  
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final header = (_negara != null && _negeri != null) ? '$_negara $_negeri' : null;

    return Scaffold(

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Image.asset(
                'assets/images/luckygo_logo.png',
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            if (header != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  header,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: t.phoneNumber,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // TextField(
            //   controller: _passwordController,
            //   decoration: const InputDecoration(
            //     labelText: 'Password',
            //     border: OutlineInputBorder(),
            //   ),
            //   obscureText: true,
            // ),

TextField(
  controller: _passwordController,
  decoration: InputDecoration(
    labelText: t.password,
    border: const OutlineInputBorder(),
  ),
  obscureText: true,
),


            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onLoginPressed,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.login),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.notMember),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const RegisterPage()),
                    );
                    // Navigator.of(context).push(
                    //   MaterialPageRoute(builder: (context) => const RegisterWithOtp()),
                    // );
                  },
                  child: Text(
                    t.registerHere,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onLoginPressed() async {
    setState(() => _isLoading = true);
    String? err;
    String? authedEmail;

    // 1) Build authEmail from input first
    final rawInput = _emailController.text.trim();
    final authEmail = _toAuthEmail(rawInput);

    // 2) Pre-check for existing session (another device)
    final okToProceed = await _confirmSingleSession(authEmail);
    if (!okToProceed) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return; // user chose Cancel
    }

    // 3) Proceed with login + driver assertion
    try {
      authedEmail = await _loginAndAssertDriverAccount();
    } catch (e) {
      err = e.toString();
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    // 4) Save/merge this device into login_sessions and navigate
    if (err == null && authedEmail != null) {
      try {
        await _saveLoginSession(email: authedEmail);
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
      return;
    }

    // Error handling
    final parts = (err ?? '').split('|');
    final code = parts.length > 1 ? parts[0] : 'ERROR';
    final message = parts.length > 1 ? parts[1] : (err ?? 'Unknown error');

    switch (code) {
      case 'REGION_MISSING':
        await _showError('Region Required', message);
        break;
      case 'INPUT_MISSING':
        await _showError('Missing Info', message);
        break;
      case 'AUTH':
        await _showError('Login Failed', message);
        break;
      case 'DOC':
        await _showError('Account Not Found', message);
        break;
      default:
        await _showError('Error', message);
    }
  }



  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
