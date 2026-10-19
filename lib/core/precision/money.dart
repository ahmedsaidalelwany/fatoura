import 'package:decimal/decimal.dart';
import 'package:fatoura/core/precision/currency.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';

/// Immutable high-precision Money value object.
/// Eliminates binary floating-point representation bugs (e.g. 0.1 + 0.2 = 0.30000000000000004).
///
/// **Default Currency:** Egyptian Pound (`EGP`), where `1 EGP = 100 piastres`.
class Money implements Comparable<Money> {
  final Decimal value;
  final String currency;

  const Money._(this.value, this.currency);

  factory Money.fromDecimal(
    Decimal value, [
    String currency = AppCurrencies.defaultCurrency,
  ]) {
    return Money._(value, currency);
  }

  factory Money.fromNum(
    num amount, [
    String currency = AppCurrencies.defaultCurrency,
  ]) {
    return Money._(Decimal.parse(amount.toString()), currency);
  }

  factory Money.fromString(
    String amount, [
    String currency = AppCurrencies.defaultCurrency,
  ]) {
    final sanitized = amount.trim().replaceAll(',', '');
    if (sanitized.isEmpty) {
      return Money._(Decimal.zero, currency);
    }
    try {
      return Money._(Decimal.parse(sanitized), currency);
    } catch (_) {
      throw ArgumentError(
        'Invalid monetary string: "$amount". '
        'Cannot silently convert non-numeric input to zero.',
      );
    }
  }

  /// Instantiates a Money object from integer minor units (e.g. 10000 piastres -> 100.00 EGP).
  factory Money.fromMinorUnits(
    int minorUnits, [
    String currency = AppCurrencies.defaultCurrency,
  ]) {
    final info = AppCurrencies.get(currency);
    return Money._(info.fromMinorUnits(minorUnits), currency);
  }

  /// Instantiates a Money object specifically from Egyptian piastres (1 EGP = 100 piastres).
  factory Money.fromPiastres(int piastres) {
    return Money.fromMinorUnits(piastres, 'EGP');
  }

  static Money zero([String currency = AppCurrencies.defaultCurrency]) =>
      Money._(Decimal.zero, currency);

  Money copyWith({Decimal? value, String? currency}) {
    return Money._(value ?? this.value, currency ?? this.currency);
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money._(value + other.value, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money._(value - other.value, currency);
  }

  Money operator *(Decimal multiplier) {
    return Money._(value * multiplier, currency);
  }

  Money operator /(Decimal divisor) {
    if (divisor == Decimal.zero) {
      throw ArgumentError('Division by zero in Money calculation.');
    }
    final info = AppCurrencies.get(currency);
    final res = (value / divisor).toDecimal(
      scaleOnInfinitePrecision: info.decimalDigits + 2,
    );
    return Money._(res, currency);
  }

  bool get isZero => value == Decimal.zero;
  bool get isNegative => value < Decimal.zero;
  bool get isPositive => value > Decimal.zero;

  double toDouble() => value.toDouble();

  /// Converts this amount into integer minor units (e.g. 100.00 EGP -> 10000 piastres).
  int toMinorUnits() {
    final info = AppCurrencies.get(currency);
    return info.toMinorUnits(value);
  }

  /// Converts this amount into Egyptian piastres if currency is EGP.
  int toPiastres() {
    return toMinorUnits();
  }

  /// Formats the money to fixed decimal places (default based on currency)
  String toStringAsFixed([int? fractionDigits]) {
    final digits = fractionDigits ?? AppCurrencies.get(currency).decimalDigits;
    return value.toStringAsFixed(digits);
  }

  /// Formats according to centralized currency standards.
  String format({bool isArabic = false, bool useFullName = false}) {
    return CurrencyFormatter.formatMoney(
      this,
      isArabic: isArabic,
      useFullName: useFullName,
    );
  }

  /// Legacy display with symbol/code
  String formatDisplay([int? fractionDigits]) {
    return format();
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Cannot perform arithmetic on different currencies: $currency vs ${other.currency}',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return value.compareTo(other.value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          currency == other.currency;

  @override
  int get hashCode => value.hashCode ^ currency.hashCode;

  @override
  String toString() => '$value $currency';
}
