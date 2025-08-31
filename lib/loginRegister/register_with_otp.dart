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

/// Phone-OTP based registration flow
class RegisterWithOtp extends StatefulWidget {
  static Future<void> ensureFirebaseInitialized() async {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }

  const RegisterWithOtp({super.key});

  @override
  State<RegisterWithOtp> createState() => _RegisterWithOtpState();
}

class _RegisterWithOtpState extends State<RegisterWithOtp> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final fullnameController       = TextEditingController();
  final phoneController          = TextEditingController(); // should be in E.164 format: +6012xxxxxxx
  final passwordController       = TextEditingController(); // kept for your UI (not used for Auth creation)
  final retypePasswordController = TextEditingController();
  final secondPhoneController    = TextEditingController();

  // Dropdown state
  String? selectedCountry;
  String? selectedState;
  String? selectedArea;
  String? selectedLanguageDisplay;

  // Gender
  String? _gender; // 'male' / 'female'

  // OTP state
  String? _verificationId;
  int? _resendToken;
  bool _codeSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  // OTP input
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    fullnameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    retypePasswordController.dispose();
    secondPhoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ----------------------- FLOW -----------------------
  // 1) Validate form → request OTP
  Future<void> _onGetOtpPressed() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender')),
      );
      return;
    }

    // Basic phone guard
    final phone = phoneController.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone must include country code, e.g. +6012xxxxxxx')),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      await RegisterWithOtp.ensureFirebaseInitialized();

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android may auto-verify without user input
          await _signInWithPhoneCredential(credential, auto: true);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isSendingOtp = false);
          _showErrorDialog('OTP Error', e.message ?? e.code);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isSendingOtp = false;
          });
          _showOtpSheet(); // open OTP entry
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Keep the verificationId; user can still type the code
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isSendingOtp = false);
      _showErrorDialog('OTP Error', e.toString());
    }
  }

  // 2) User types OTP → verify
  Future<void> _onConfirmOtpPressed() async {
    final code = _otpController.text.trim();
    if ((_verificationId ?? '').isEmpty || code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP')),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signInWithPhoneCredential(credential, auto: false);
      if (mounted) Navigator.of(context).pop(); // close bottom sheet
    } catch (e) {
      setState(() => _isVerifyingOtp = false);
      _showErrorDialog('Verification Failed', e.toString());
    }
  }

  // 3) After successful sign-in with phone, save profile & activate
  Future<void> _postSignInAndSaveProfile() async {
    final country  = selectedCountry ?? 'unknown_country';
    final state    = selectedState ?? 'unknown_state';
    final area     = selectedArea ?? 'unknown_area';
    final language = selectedLanguageDisplay ?? 'unknown_language';
    final gender   = _gender ?? 'unknown';
    final loc      = AppLocalizations.of(context)!;

    final phone    = phoneController.text.trim();
    final name     = fullnameController.text.trim();

    // We keep your email scheme for UI consistency & displayName storage,
    // but we DO NOT create email/password users anymore.
    final email = '$phone@driver.com';

    try {
      // Set displayName on the Phone user (not guaranteed on iOS until reload)
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      await FirebaseAuth.instance.currentUser?.reload();

      // Update session/globals
      await SessionManager.updateFromAuthCurrentUser();
      Gv.userName   = name;
      Gv.loggedUser = phone;

      // Firestore driver profile
      final data = {
        'account_balance': 0,
        'area': area,
        'country': country,
        'created_at': DateTime.now().toIso8601String(),
        'com_fixed_or_percentage': false,
        'commission_percentage': 10,
        'commission_fixed': 1,
        'disclosureAccepted': false,
        'email': email,
        'fullname': name,
        'gender': gender,
        'group_capability': 3,
        'language': language,
        'must_exit_block_zone': false,
        'registration_approved': false,
        'state': state,
        'phone_e164': phone, // store verified phone
        'status': 'active',  // mark activated after OTP verified
        'updated_at': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection(country)
          .doc(state)
          .collection('driver_account')
          .doc(phone)
          .set(data, SetOptions(merge: true));

      // Persist region locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('country', country);
      await prefs.setString('state', state);
      await prefs.setString('area', area);
      await prefs.setString('language', language);

      if (!mounted) return;
      _showSuccessDialog(
        title: loc.register,
        message: 'Registration successful! Your phone number has been verified.',
        onOk: () {
          Navigator.of(context).pop();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        },
      );
    } catch (e) {
      _showErrorDialog('Firestore Error', e.toString());
    }
  }

  // Sign-in helper (used by auto & manual verification)
  Future<void> _signInWithPhoneCredential(PhoneAuthCredential credential, {required bool auto}) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      // If we reach here, OTP verified & user is signed in
      setState(() {
        _isSendingOtp = false;
        _isVerifyingOtp = false;
      });
      await _postSignInAndSaveProfile();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isSendingOtp = false;
        _isVerifyingOtp = false;
      });
      _showErrorDialog('Sign-in Failed', e.message ?? e.code);
    }
  }

  // ----------------------- UI -----------------------
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.register)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(loc.fullName, fullnameController),
              _buildTextField(loc.phoneNo, phoneController,
                  keyboardType: TextInputType.phone),
              // keep these fields for your layout; not used for Auth creation
              _buildTextField(loc.pwd, passwordController, obscureText: true),
              _buildTextField(loc.rePwd, retypePasswordController, obscureText: true),
              _buildTextField(loc.phone2, secondPhoneController,
                  keyboardType: TextInputType.phone, isOptional: true),

              _buildGenderSelector(),

              _buildCountryDropdown(),
              if (selectedCountry != null) _buildStateDropdown(),
              if (selectedState != null) _buildAreaDropdown(),
              if (selectedArea != null) _buildLanguageDropdown(),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isSendingOtp ? null : _onGetOtpPressed,
                child: _isSendingOtp
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_codeSent ? 'Resend OTP' : loc.register),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 8),
                Text(
                  'OTP sent to ${phoneController.text.trim()}. Tap to resend if needed.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(loc.member),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(loc.loginHere, style: const TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Pieces -----
  Widget _buildGenderSelector() {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.gender, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.male),
                  value: 'male',
                  groupValue: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.female),
                  value: 'female',
                  groupValue: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
            ],
          ),
        ],
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
          border: const OutlineInputBorder(),
        ),
        items: countries
            .map((country) => DropdownMenuItem(value: country, child: Text(country)))
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
          if (value == null || value.isEmpty) return 'Please select a country';
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
          border: const OutlineInputBorder(),
        ),
        items: states
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedState = value;
            selectedArea = null;
            selectedLanguageDisplay = null;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please select a state';
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
        items: areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
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
          border: OutlineInputBorder(),
        ),
        items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
        onChanged: (value) => setState(() => selectedLanguageDisplay = value),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please select a language';
          return null;
        },
      ),
    );
  }

  // ----- OTP Sheet -----
  void _showOtpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter OTP sent to ${phoneController.text.trim()}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
                maxLength: 6,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isVerifyingOtp ? null : _onConfirmOtpPressed,
                      child: _isVerifyingOtp
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm OTP'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _isSendingOtp
                    ? null
                    : () async {
                        Navigator.of(context).pop(); // close sheet before resending
                        await _onGetOtpPressed();
                      },
                child: _isSendingOtp
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend OTP'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----- Dialog helpers -----
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  void _showSuccessDialog({required String title, required String message, VoidCallback? onOk}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOk?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
