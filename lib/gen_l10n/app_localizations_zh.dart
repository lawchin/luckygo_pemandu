// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Lucky Go Driver';

  @override
  String get phoneNumber => '手机号';

  @override
  String get password => '密码';

  @override
  String get notMember => '还不是会员？';

  @override
  String get registerHere => '在这里注册！';

  @override
  String get login => '登录';

  @override
  String get td => '条款与披露';

  @override
  String get beforeUsing =>
      '在使用本应用程序之前，请阅读并接受我们的数据使用披露。我们可能会收集您的账户信息、设备信息和位置信息，以便为您提供服务。您的数据将被妥善保护，除非法律要求，否则不会与第三方共享。继续操作即表示您已知晓并接受这些条款。';

  @override
  String get iAccept => '我接受披露条款';

  @override
  String get cont => '继续';

  @override
  String get welcome => '欢迎';

  @override
  String get notProvided => '未提供';
}
