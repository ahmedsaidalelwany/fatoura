/// Authoritative configuration for developer/publisher information.
///
/// Follows strict honesty principles: does not include placeholder or fake names,
/// emails, or social profiles. When not configured, provides clear, neutral
/// status messaging in both Arabic and English.
class DeveloperConfig {
  DeveloperConfig._();

  /// Flag indicating whether developer/organization details have been explicitly configured.
  static const bool isConfigured = true;

  /// Configured developer metadata
  static const String developerName = 'Ahmed Said Khaled';
  static const String developerEmail = 'ahmedsaidalalwani1@gmail.com';
  static const String developerTelegram = '@asx_03';
  static const String developerWebsite = '';
  static const String githubUrl = '';
  static const String supportContact = '@asx_03';

  // Localized unconfigured strings
  static const String unconfiguredTitleAr = 'معلومات المطور';
  static const String unconfiguredTitleEn = 'Developer Information';
  static const String unconfiguredMessageAr = 'معلومات المطور لم يتم تهيئتها بعد.';
  static const String unconfiguredMessageEn =
      'Developer information has not been configured yet.';
  static const String unconfiguredSubtitleAr =
      'هذا التطبيق مبني كبرنامج محلي بالكامل ومفتوح المعايير. يمكنك تخصيص معلومات الناشر من خلال ملف الإعدادات البرمجية.';
  static const String unconfiguredSubtitleEn =
      'This application is built as an offline-first, local-only business tool. Publisher details can be specified in the developer configuration file.';

  // Architectural & Technical specifications displayed honestly to users & developers
  static const String appName = 'فاتورة / Fatoura';
  static const String appVersion = '1.0.0+1';
  static const String framework = 'Flutter & Dart';
  static const String architecture = 'Clean Architecture + BLoC / Cubit Pattern';
  static const String databaseEngine = 'Sembast (Local-first NoSQL Document Storage)';
  static const String precisionEngine = 'Decimal (Arbitrary Precision Financial Math)';
  static const String targetPlatforms = 'Android & Windows Desktop';
  static const String license = 'Proprietary / Open Business Edition';
}
