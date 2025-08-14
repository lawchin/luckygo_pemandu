// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lucky Go Driver';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get password => 'Password';

  @override
  String get notMember => 'Not yet a member?';

  @override
  String get registerHere => 'Register here!';

  @override
  String get login => 'Login';

  @override
  String get td => 'Terms & Disclosure';

  @override
  String get beforeUsing =>
      'Before using this application, please review and accept our data usage disclosure.We may collect your account information, device information, and location information to provide you with our services.Your data will be properly protected and will not be shared with third parties unless required by law.By continuing, you acknowledge and accept these terms.';

  @override
  String get iAccept => 'I accept the disclosure terms';

  @override
  String get cont => 'Continue';

  @override
  String get welcome => 'Welcome';

  @override
  String get notProvided => 'NOT PROVIDED';
}
