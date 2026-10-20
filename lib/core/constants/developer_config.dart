/// Authoritative configuration for developer/publisher information.
///
/// Follows strict integrity principles: accurately presents the developer identity,
/// contact details, license, and technical architectural stack.
class DeveloperConfig {
  DeveloperConfig._();

  /// Developer identity details
  static const String developerName = 'Ahmed Said Khaled';
  static const String developerEmail = 'ahmedsaidalelwany1@gmail.com';
  static const String developerTelegram = '@asx_03';
  static const String developerTelegramUrl = 'https://t.me/asx_03';
  static const String developerWebsite = '';
  static const String githubUrl =
      'https://github.com/ahmedsaidalelwany/fatoura';
  static const String supportContact = '@asx_03';

  // Architectural & Technical specifications displayed honestly to users & developers
  static const String appName = 'فاتورة / Fatoura';
  static const String appVersion = '1.0.0+1';
  static const String framework = 'Flutter & Dart';
  static const String architecture =
      'Clean Architecture + BLoC / Cubit Pattern';
  static const String databaseEngine = 'Hive (Local-first Key-Value Store)';
  static const String precisionEngine =
      'Decimal (Arbitrary Precision Financial Math)';
  static const String targetPlatforms = 'Android & Windows Desktop';
  static const String license = 'MIT License';
}
