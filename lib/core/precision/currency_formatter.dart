import 'package:decimal/decimal.dart';
import 'package:fatoura/core/precision/currency.dart';
import 'package:fatoura/core/precision/money.dart';

/// Centralized, authoritative currency formatter for Fatoura.
/// Ensures standard formatting across Dashboard, Invoices, Payments, Reports, and PDFs.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats a numeric value (e.g. 100.00) with currency code/symbol.
  ///
  /// Examples:
  /// - Arabic: `100.00 ج.م`
  /// - English: `EGP 100.00`
  static String format(
    num amount, {
    String currency = AppCurrencies.defaultCurrency,
    bool isArabic = false,
    bool useFullName = false,
  }) {
    final info = AppCurrencies.get(currency);
    final formattedNumber = amount.toStringAsFixed(info.decimalDigits);

    if (isArabic) {
      final symbol = useFullName ? info.nameAr : info.symbolAr;
      return '$formattedNumber $symbol';
    } else {
      if (useFullName) {
        return '$formattedNumber ${info.nameEn}';
      }
      return '${info.symbolEn} $formattedNumber';
    }
  }

  /// Formats an exact Decimal amount.
  static String formatDecimal(
    Decimal amount, {
    String currency = AppCurrencies.defaultCurrency,
    bool isArabic = false,
    bool useFullName = false,
  }) {
    final info = AppCurrencies.get(currency);
    final formattedNumber = amount.toStringAsFixed(info.decimalDigits);

    if (isArabic) {
      final symbol = useFullName ? info.nameAr : info.symbolAr;
      return '$formattedNumber $symbol';
    } else {
      if (useFullName) {
        return '$formattedNumber ${info.nameEn}';
      }
      return '${info.symbolEn} $formattedNumber';
    }
  }

  /// Formats an immutable Money object.
  static String formatMoney(
    Money money, {
    bool isArabic = false,
    bool useFullName = false,
  }) {
    return formatDecimal(
      money.value,
      currency: money.currency,
      isArabic: isArabic,
      useFullName: useFullName,
    );
  }

  /// Formats integer minor units (e.g. 2550 piastres -> `25.50 ج.م` / `EGP 25.50`).
  static String formatMinorUnits(
    int minorUnits, {
    String currency = AppCurrencies.defaultCurrency,
    bool isArabic = false,
    bool useFullName = false,
  }) {
    final info = AppCurrencies.get(currency);
    final decimal = info.fromMinorUnits(minorUnits);
    return formatDecimal(
      decimal,
      currency: currency,
      isArabic: isArabic,
      useFullName: useFullName,
    );
  }

  /// Localized currency display name (e.g. "الجنيه المصري (EGP)" or "Egyptian Pound (EGP)").
  static String getLocalizedDisplayName(
    String currency, {
    bool isArabic = false,
  }) {
    final info = AppCurrencies.get(currency);
    if (isArabic) {
      return '${info.nameAr} (${info.code})';
    } else {
      return '${info.nameEn} (${info.code})';
    }
  }
}
