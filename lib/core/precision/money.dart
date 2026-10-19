import 'package:decimal/decimal.dart';

/// Immutable high-precision Money value object.
/// Eliminates binary floating-point representation bugs (e.g. 0.1 + 0.2 = 0.30000000000000004).
class Money implements Comparable<Money> {
  final Decimal value;
  final String currency;

  const Money._(this.value, this.currency);

  factory Money.fromDecimal(Decimal value, [String currency = 'SAR']) {
    return Money._(value, currency);
  }

  factory Money.fromNum(num amount, [String currency = 'SAR']) {
    return Money._(Decimal.parse(amount.toString()), currency);
  }

  factory Money.fromString(String amount, [String currency = 'SAR']) {
    try {
      final sanitized = amount.trim().replaceAll(',', '');
      if (sanitized.isEmpty) {
        return Money._(Decimal.zero, currency);
      }
      return Money._(Decimal.parse(sanitized), currency);
    } catch (_) {
      return Money._(Decimal.zero, currency);
    }
  }

  static Money zero([String currency = 'SAR']) =>
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
    // Round to 4 decimal places internally
    final res = (value / divisor).toDecimal(scaleOnInfinitePrecision: 4);
    return Money._(res, currency);
  }

  bool get isZero => value == Decimal.zero;
  bool get isNegative => value < Decimal.zero;
  bool get isPositive => value > Decimal.zero;

  double toDouble() => value.toDouble();

  /// Formats the money to fixed decimal places (default 2)
  String toStringAsFixed([int fractionDigits = 2]) {
    return value.toStringAsFixed(fractionDigits);
  }

  /// User-facing display with currency symbol or code
  String formatDisplay([int fractionDigits = 2]) {
    final formattedNumber = toStringAsFixed(fractionDigits);
    return '$formattedNumber $currency';
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
