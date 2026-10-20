import 'package:decimal/decimal.dart';

/// Metadata definition for a supported currency in Fatoura.
class CurrencyInfo {
  final String code; // ISO 4217 code (e.g. EGP, SAR, USD)
  final String symbolAr; // Arabic symbol (e.g. ج.م, ر.س, $)
  final String symbolEn; // English symbol (e.g. EGP, SAR, USD)
  final String nameAr; // Arabic full name (e.g. الجنيه المصري)
  final String nameEn; // English full name (e.g. Egyptian Pound)
  final String majorUnitAr; // e.g. جنيه
  final String majorUnitEn; // e.g. Pound
  final String minorUnitAr; // e.g. قرش
  final String minorUnitEn; // e.g. Piastre
  final int minorUnitFactor; // e.g. 100 (1 EGP = 100 piastres)
  final int decimalDigits; // e.g. 2

  const CurrencyInfo({
    required this.code,
    required this.symbolAr,
    required this.symbolEn,
    required this.nameAr,
    required this.nameEn,
    required this.majorUnitAr,
    required this.majorUnitEn,
    required this.minorUnitAr,
    required this.minorUnitEn,
    this.minorUnitFactor = 100,
    this.decimalDigits = 2,
  });

  /// Converts a major decimal amount to integer minor units (e.g. 100.00 EGP -> 10000 piastres).
  /// Applies deterministic half-up rounding to prevent truncation loss.
  int toMinorUnits(Decimal majorAmount) {
    final scaled = majorAmount * Decimal.fromInt(minorUnitFactor);
    final isNegative = scaled < Decimal.zero;
    final absScaled = isNegative ? -scaled : scaled;
    final half = Decimal.parse('0.5');
    final rounded = (absScaled + half).toBigInt();
    final result = isNegative ? -rounded : rounded;
    return result.toInt();
  }

  /// Converts integer minor units to major decimal amount (e.g. 10000 piastres -> 100.00 EGP)
  Decimal fromMinorUnits(int minorUnits) {
    return (Decimal.fromInt(minorUnits) / Decimal.fromInt(minorUnitFactor))
        .toDecimal(scaleOnInfinitePrecision: decimalDigits);
  }
}

/// Authoritative currency registry for Fatoura.
///
/// **Default Currency:** Egyptian Pound (`EGP`)
/// Major unit: Pound (جنيه)
/// Minor unit: Piastre (قرش)
/// Conversion: `1 EGP = 100 piastres`
///
/// Piastres are a subdivision of the Egyptian pound, not a separate currency.
class AppCurrencies {
  AppCurrencies._();

  static const String defaultCurrency = 'EGP';

  /// Egyptian Pound (Default)
  static const CurrencyInfo egp = CurrencyInfo(
    code: 'EGP',
    symbolAr: 'ج.م',
    symbolEn: 'EGP',
    nameAr: 'الجنيه المصري',
    nameEn: 'Egyptian Pound',
    majorUnitAr: 'جنيه',
    majorUnitEn: 'Pound',
    minorUnitAr: 'قرش',
    minorUnitEn: 'Piastre',
    minorUnitFactor: 100,
    decimalDigits: 2,
  );

  /// Saudi Riyal
  static const CurrencyInfo sar = CurrencyInfo(
    code: 'SAR',
    symbolAr: 'ر.س',
    symbolEn: 'SAR',
    nameAr: 'الريال السعودي',
    nameEn: 'Saudi Riyal',
    majorUnitAr: 'ريال',
    majorUnitEn: 'Riyal',
    minorUnitAr: 'هللة',
    minorUnitEn: 'Halala',
    minorUnitFactor: 100,
    decimalDigits: 2,
  );

  /// UAE Dirham
  static const CurrencyInfo aed = CurrencyInfo(
    code: 'AED',
    symbolAr: 'د.إ',
    symbolEn: 'AED',
    nameAr: 'الدرهم الإماراتي',
    nameEn: 'UAE Dirham',
    majorUnitAr: 'درهم',
    majorUnitEn: 'Dirham',
    minorUnitAr: 'فلس',
    minorUnitEn: 'Fils',
    minorUnitFactor: 100,
    decimalDigits: 2,
  );

  /// US Dollar
  static const CurrencyInfo usd = CurrencyInfo(
    code: 'USD',
    symbolAr: '\$',
    symbolEn: 'USD',
    nameAr: 'الدولار الأمريكي',
    nameEn: 'US Dollar',
    majorUnitAr: 'دولار',
    majorUnitEn: 'Dollar',
    minorUnitAr: 'سنت',
    minorUnitEn: 'Cent',
    minorUnitFactor: 100,
    decimalDigits: 2,
  );

  /// Euro
  static const CurrencyInfo eur = CurrencyInfo(
    code: 'EUR',
    symbolAr: '€',
    symbolEn: 'EUR',
    nameAr: 'اليورو',
    nameEn: 'Euro',
    majorUnitAr: 'يورو',
    majorUnitEn: 'Euro',
    minorUnitAr: 'سنت',
    minorUnitEn: 'Cent',
    minorUnitFactor: 100,
    decimalDigits: 2,
  );

  /// Kuwaiti Dinar
  static const CurrencyInfo kwd = CurrencyInfo(
    code: 'KWD',
    symbolAr: 'د.ك',
    symbolEn: 'KWD',
    nameAr: 'الدينار الكويتي',
    nameEn: 'Kuwaiti Dinar',
    majorUnitAr: 'دينار',
    majorUnitEn: 'Dinar',
    minorUnitAr: 'فلس',
    minorUnitEn: 'Fils',
    minorUnitFactor: 1000,
    decimalDigits: 3,
  );

  /// Qatari Riyal
  static const CurrencyInfo qar = CurrencyInfo(
    code: 'QAR',
    symbolAr: 'ر.ق',
    symbolEn: 'QAR',
    nameAr: 'الريال القطري',
    nameEn: 'Qatari Riyal',
    majorUnitAr: 'ريال',
    majorUnitEn: 'Riyal',
    minorUnitAr: 'درهم',
    minorUnitEn: 'Dirham',
    minorUnitFactor: 100,
    decimalDigits: 2,
  );

  static const List<CurrencyInfo> supported = [
    egp,
    sar,
    aed,
    usd,
    eur,
    kwd,
    qar,
  ];

  static List<String> get supportedCurrencyCodes =>
      supported.map((c) => c.code).toList();

  static final Map<String, CurrencyInfo> _byCode = {
    for (final c in supported) c.code.toUpperCase(): c,
  };

  /// Retrieves currency metadata by ISO code.
  /// If [code] is null, defaults to [defaultCurrency] (`EGP`).
  /// Throws [ArgumentError] if [code] is unrecognized, preventing silent currency misinterpretation.
  static CurrencyInfo get(String? code) {
    if (code == null) return egp;
    final trimmed = code.trim().toUpperCase();
    final info = _byCode[trimmed];
    if (info == null) {
      throw ArgumentError(
        'Unsupported currency code: "$code". Supported currencies: $supportedCurrencyCodes',
      );
    }
    return info;
  }

  /// Safely attempts to retrieve currency metadata by ISO code without throwing.
  static CurrencyInfo? tryGet(String? code) {
    if (code == null) return null;
    return _byCode[code.trim().toUpperCase()];
  }

  /// Checks if the given currency code is officially supported.
  static bool isSupported(String? code) {
    if (code == null) return false;
    return _byCode.containsKey(code.trim().toUpperCase());
  }

  /// Converts piastres to EGP Decimal amount (e.g. 2550 -> 25.50)
  static Decimal piastresToEgp(int piastres) {
    return egp.fromMinorUnits(piastres);
  }

  /// Converts EGP Decimal amount to integer piastres (e.g. 25.50 -> 2550)
  static int egpToPiastres(Decimal egpAmount) {
    return egp.toMinorUnits(egpAmount);
  }
}
