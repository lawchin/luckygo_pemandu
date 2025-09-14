import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ms'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Lucky Go Driver'**
  String get appTitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @notMember.
  ///
  /// In en, this message translates to:
  /// **'Not yet a member?'**
  String get notMember;

  /// No description provided for @registerHere.
  ///
  /// In en, this message translates to:
  /// **'Register here!'**
  String get registerHere;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @td.
  ///
  /// In en, this message translates to:
  /// **'Terms & Disclosure'**
  String get td;

  /// No description provided for @beforeUsing.
  ///
  /// In en, this message translates to:
  /// **'Before using this application, please review and accept our data usage disclosure.We may collect your account information, device information, and location information to provide you with our services.Your data will be properly protected and will not be shared with third parties unless required by law.By continuing, you acknowledge and accept these terms.'**
  String get beforeUsing;

  /// No description provided for @iAccept.
  ///
  /// In en, this message translates to:
  /// **'I accept the disclosure terms'**
  String get iAccept;

  /// No description provided for @cont.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get cont;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'NOT PROVIDED'**
  String get notProvided;

  /// No description provided for @icNo.
  ///
  /// In en, this message translates to:
  /// **'Enter IC number'**
  String get icNo;

  /// No description provided for @driverLicenseExDate.
  ///
  /// In en, this message translates to:
  /// **'Enter driver license expiry date'**
  String get driverLicenseExDate;

  /// No description provided for @roadTaxExDate.
  ///
  /// In en, this message translates to:
  /// **'Enter road tax expiry date'**
  String get roadTaxExDate;

  /// No description provided for @psvExDate.
  ///
  /// In en, this message translates to:
  /// **'Enter PSV expiry date'**
  String get psvExDate;

  /// No description provided for @eInsExDate.
  ///
  /// In en, this message translates to:
  /// **'Enter e-hailing insurance expiry date'**
  String get eInsExDate;

  /// No description provided for @imgSelfie.
  ///
  /// In en, this message translates to:
  /// **'Image Selfie'**
  String get imgSelfie;

  /// No description provided for @carFront.
  ///
  /// In en, this message translates to:
  /// **'Car Infront'**
  String get carFront;

  /// No description provided for @carBack.
  ///
  /// In en, this message translates to:
  /// **'Car Back'**
  String get carBack;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @completeReg.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeReg;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @vePlateNo.
  ///
  /// In en, this message translates to:
  /// **'Vehicle plate number'**
  String get vePlateNo;

  /// No description provided for @veBrand.
  ///
  /// In en, this message translates to:
  /// **'Vehicle brand'**
  String get veBrand;

  /// No description provided for @veModel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle model'**
  String get veModel;

  /// No description provided for @veColor.
  ///
  /// In en, this message translates to:
  /// **'Vehicle color'**
  String get veColor;

  /// No description provided for @veCapacity.
  ///
  /// In en, this message translates to:
  /// **'Vehicle capacity'**
  String get veCapacity;

  /// No description provided for @pendingReviewText.
  ///
  /// In en, this message translates to:
  /// **'Waiting for admin to review your documents.\nOnce approved, you will be notified and can proceed to use the app.'**
  String get pendingReviewText;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReview;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneNo.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNo;

  /// No description provided for @pwd.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get pwd;

  /// No description provided for @rePwd.
  ///
  /// In en, this message translates to:
  /// **'Re-Type Password'**
  String get rePwd;

  /// No description provided for @phone2.
  ///
  /// In en, this message translates to:
  /// **'2nd Phone Number (Optional)'**
  String get phone2;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @area.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get area;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Already a member?'**
  String get member;

  /// No description provided for @loginHere.
  ///
  /// In en, this message translates to:
  /// **'Login here!'**
  String get loginHere;

  /// No description provided for @plsReload.
  ///
  /// In en, this message translates to:
  /// **'Please reload your account'**
  String get plsReload;

  /// No description provided for @balanceIs.
  ///
  /// In en, this message translates to:
  /// **'Your balance is'**
  String get balanceIs;

  /// No description provided for @viewActiveJob.
  ///
  /// In en, this message translates to:
  /// **'View Active Job'**
  String get viewActiveJob;

  /// No description provided for @noJob.
  ///
  /// In en, this message translates to:
  /// **'The job is no longer available'**
  String get noJob;

  /// No description provided for @nextToYou.
  ///
  /// In en, this message translates to:
  /// **'Next to you'**
  String get nextToYou;

  /// No description provided for @veryNear.
  ///
  /// In en, this message translates to:
  /// **'Very Near'**
  String get veryNear;

  /// No description provided for @quiteNear.
  ///
  /// In en, this message translates to:
  /// **'Quite Near'**
  String get quiteNear;

  /// No description provided for @stillReachable.
  ///
  /// In en, this message translates to:
  /// **'Still Reachable'**
  String get stillReachable;

  /// No description provided for @nearbyZone.
  ///
  /// In en, this message translates to:
  /// **'Nearby Zone'**
  String get nearbyZone;

  /// No description provided for @below.
  ///
  /// In en, this message translates to:
  /// **'• 1.5km and below'**
  String get below;

  /// No description provided for @oneFive.
  ///
  /// In en, this message translates to:
  /// **'• 1.5km - 3km'**
  String get oneFive;

  /// No description provided for @three.
  ///
  /// In en, this message translates to:
  /// **'• 3km - 5km'**
  String get three;

  /// No description provided for @five.
  ///
  /// In en, this message translates to:
  /// **'• 5km - 7.5km (Fly)'**
  String get five;

  /// No description provided for @seven.
  ///
  /// In en, this message translates to:
  /// **'• 7.5km - 10km (Fly)'**
  String get seven;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ms', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ms':
      return AppLocalizationsMs();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
