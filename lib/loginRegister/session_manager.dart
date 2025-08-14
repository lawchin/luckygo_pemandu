import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../global.dart';

class SessionManager {
  static const _kLoggedUserKey = 'loggedUser';
  static const _kUserNameKey   = 'userName';

  /// Call this AFTER Firebase.initializeApp() (e.g., in main.dart).
  /// Loads saved data, syncs with current user, and listens to auth changes.
  static Future<void> bootstrap() async {
    await _loadFromPrefs();
    await updateFromAuthCurrentUser();

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        // Logged out
        Gv.loggedUser = '';
        Gv.userName = '';
        await _saveToPrefs('', '');
      } else {
        await _applyUser(user);
      }
    });
  }

  /// Call this after successful register/login to refresh Gv + prefs.
  static Future<void> updateFromAuthCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _applyUser(user);
    }
  }

  static Future<void> _applyUser(User user) async {
    final email = user.email ?? '';
    final loggedUser = email.endsWith('@driver.com')
        ? email.replaceAll('@driver.com', '')
        : email;

    final userName = user.displayName ?? '';

    Gv.loggedUser = loggedUser;
    Gv.userName = userName;

    await _saveToPrefs(loggedUser, userName);
  }

  static Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    Gv.loggedUser = prefs.getString(_kLoggedUserKey) ?? '';
    Gv.userName   = prefs.getString(_kUserNameKey) ?? '';
  }

  static Future<void> _saveToPrefs(String loggedUser, String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLoggedUserKey, loggedUser);
    await prefs.setString(_kUserNameKey, userName);
  }

  /// Optional: call on explicit logout to clear values quickly.
  static Future<void> clear() async {
    Gv.loggedUser = '';
    Gv.userName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoggedUserKey);
    await prefs.remove(_kUserNameKey);
  }
}
