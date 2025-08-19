import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';
import 'package:luckygo_pemandu/loginRegister/session_manager.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'login_page.dart';
import 'malaysia_state_area.dart';
import 'indonesia_state_area.dart';
import 'timor_leste_state_area.dart';

 // keeps Gv.loggedUser & Gv.userName synced with Auth + SharedPreferences

class RegisterPage extends StatefulWidget {
  // Ensure Firebase is initialized before using any Firebase service
  static Future<void> ensureFirebaseInitialized() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Already initialized or error
    }
  }

  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Register user: Auth, Firestore, and local storage, with error dialogs
  Future<void> registerUser() async {
    final country  = selectedCountry ?? 'unknown_country';
    final state    = selectedState ?? 'unknown_state';
    final area     = selectedArea ?? 'unknown_area';
    final language = selectedLanguageDisplay ?? 'unknown_language';

    final phone    = phoneController.text.isNotEmpty ? phoneController.text : 'unknown_phone';
    final email    = '$phone@driver.com';
    final name     = fullnameController.text.trim();
    final password = passwordController.text.isNotEmpty ? passwordController.text : 'defaultPassword123';

    try {
      // Create Auth account
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save displayName to Auth
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      // Make sure currentUser reflects latest profile
      await FirebaseAuth.instance.currentUser?.reload();

      // ✅ Update globals + persist to SharedPreferences via SessionManager
      // (SessionManager maps email -> loggedUser and saves userName)
      await SessionManager.updateFromAuthCurrentUser();

      // Also set immediately in Gv (useful if UI reads it before listener fires)
      Gv.userName   = name;
      Gv.loggedUser = phone;

    } catch (e) {
      // If user already exists, try to sign in, then still set name + session
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
        await FirebaseAuth.instance.currentUser?.reload();

        await SessionManager.updateFromAuthCurrentUser();
        Gv.userName   = name;
        Gv.loggedUser = phone;

      } catch (e2) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration Error'),
            content: Text('Failed to register or sign in: \n\n${e2.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // Save user data to Firestore
    final data = {
      'email': email,
      'fullname': name,
      'country': country,
      'state': state,
      'area': area,
      'language': language,
      'created_at': DateTime.now().toIso8601String(),
      'registration_approved': false
    };
    try {
      await FirebaseFirestore.instance
          .collection(country)
          .doc(state)
          .collection('driver_account')
          .doc(phone)
          .set(data);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Firestore Error'),
          content: Text('Failed to save user data to Firestore: \n\n${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Save region to local storage (SessionManager handles userName/loggedUser)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('country', country);
      await prefs.setString('state', state);
      await prefs.setString('area', area);
      await prefs.setString('language', language);
    } catch (_) {
      // Non-critical
    }

    // Success → go to Login
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register'),
        content: const Text('Registration successful!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  final _formKey = GlobalKey<FormState>();

  final fullnameController       = TextEditingController();
  final phoneController          = TextEditingController();
  final passwordController       = TextEditingController();
  final retypePasswordController = TextEditingController();
  final secondPhoneController    = TextEditingController();

  String? selectedCountry;
  String? selectedState;
  String? selectedArea;
  String? selectedLanguageDisplay;

  @override
  void dispose() {
    fullnameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    retypePasswordController.dispose();
    secondPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {    
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(loc.fullName, fullnameController),
              _buildTextField(loc.phoneNo, phoneController, keyboardType: TextInputType.phone),
              _buildTextField(loc.pwd, passwordController, obscureText: true),
              _buildTextField(loc.rePwd, retypePasswordController, obscureText: true),
              _buildTextField(loc.phone2, secondPhoneController, keyboardType: TextInputType.phone, isOptional: true),
              _buildCountryDropdown(),
              if (selectedCountry != null) _buildStateDropdown(),
              if (selectedState != null) _buildAreaDropdown(),
              if (selectedArea != null) _buildLanguageDropdown(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onRegisterPressed,
                child: const Text("Register"),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already a member?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      "Login here!",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (!isOptional && (value == null || value.trim().isEmpty)) {
            return "Please enter $label";
          }
          if (label == "Re-type Password" && value != passwordController.text) {
            return "Passwords do not match";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCountryDropdown() {
    final loc = AppLocalizations.of(context)!;
    final countries = ['Malaysia', 'Timor-Leste', 'Indonesia'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: selectedCountry,
        decoration: InputDecoration(
          labelText: loc.country,
          border: OutlineInputBorder(),
        ),
        items: countries
            .map((country) => DropdownMenuItem(
                  value: country,
                  child: Text(country),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedCountry = value;
            selectedState = null;
            selectedArea = null;
            selectedLanguageDisplay = null;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a country';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildStateDropdown() {
    final loc = AppLocalizations.of(context)!;
    List<String> states = [];
    if (selectedCountry == 'Malaysia') {
      states = malaysiaStateAreas.keys.toList();
    } else if (selectedCountry == 'Timor-Leste') {
      states = timorLesteStateAreas.keys.toList();
    } else if (selectedCountry == 'Indonesia') {
      states = indonesiaStateAreas.keys.toList();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: selectedState,
        decoration: InputDecoration(
          labelText: loc.state,
          border: OutlineInputBorder(),
        ),
        items: states
            .map((state) => DropdownMenuItem(
                  value: state,
                  child: Text(state),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedState = value;
            selectedArea = null;
            selectedLanguageDisplay = null;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a state';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildAreaDropdown() {
    final loc = AppLocalizations.of(context)!;
    List<String> areas = [];
    if (selectedCountry == 'Malaysia' && selectedState != null) {
      areas = malaysiaStateAreas[selectedState!] ?? [];
    } else if (selectedCountry == 'Indonesia' && selectedState != null) {
      areas = indonesiaStateAreas[selectedState!] ?? [];
    } else if (selectedCountry == 'Timor-Leste' && selectedState != null) {
      areas = timorLesteStateAreas[selectedState!] ?? [];
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: selectedArea,
        decoration: InputDecoration(
          labelText: loc.area,
          border: const OutlineInputBorder(),
        ),
        items: areas
            .map((area) => DropdownMenuItem(
                  value: area,
                  child: Text(area),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedArea = value;
            selectedLanguageDisplay = null;
          });
        },
        validator: (value) {
          if (areas.isNotEmpty && (value == null || value.isEmpty)) {
            return 'Please select an area';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    List<String> languages = [];
    if (selectedCountry == 'Malaysia') {
      if (selectedState == 'Sabah') {
        languages = ['Malay', 'Chinese', 'English', 'Dusun'];
      } else {
        languages = ['Malay', 'Chinese', 'English'];
      }
    } else if (selectedCountry == 'Indonesia') {
      languages = ['Indonesian', 'Chinese', 'English', 'Javanese'];
    } else if (selectedCountry == 'Timor-Leste') {
      languages = ['Tetum', 'Portuguese', 'Indonesian', 'English', 'Fataluku'];
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: selectedLanguageDisplay,
        decoration: const InputDecoration(
          labelText: 'Language',
          border: const OutlineInputBorder(),
        ),
        items: languages
            .map((lang) => DropdownMenuItem(
                  value: lang,
                  child: Text(lang),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedLanguageDisplay = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a language';
          }
          return null;
        },
      ),
    );
  }

  void _onRegisterPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      RegisterPage.ensureFirebaseInitialized().then((_) {
        registerUser();
      });
    }
  }
}

