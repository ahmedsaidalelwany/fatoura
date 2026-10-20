import 'package:decimal/decimal.dart';
import 'package:fatoura/core/precision/currency.dart';

import 'money.dart';

enum DiscountType { fixed, percentage }

class LineItemCalculation {
  final Decimal quantity;
  final Money unitPrice;
  final Money lineTotal;

  LineItemCalculation({
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });
}

class InvoiceCalculationResult {
  final List<LineItemCalculation> items;
  final Money subtotal;
  final DiscountType discountType;
  final Decimal discountInput;
  final Money discountAmount;
  final Money taxableBase;
  final Decimal taxRate;
  final Money taxAmount;
  final Money finalTotal;

  InvoiceCalculationResult({
    required this.items,
    required this.subtotal,
    required this.discountType,
    required this.discountInput,
    required this.discountAmount,
    required this.taxableBase,
    required this.taxRate,
    required this.taxAmount,
    required this.finalTotal,
  });
}

class FinancialCalculator {
  FinancialCalculator._();

  /// Deterministic half-up rounding for [Decimal] to [scale] fraction digits.
  /// Eliminates binary floating-point rounding errors and truncation bias.
  static Decimal roundHalfUp(Decimal input, int scale) {
    if (scale < 0) {
      throw ArgumentError('Scale must be non-negative: $scale');
    }
    var factorBigInt = BigInt.one;
    for (int i = 0; i < scale; i++) {
      factorBigInt *= BigInt.from(10);
    }
    final factor = Decimal.fromBigInt(factorBigInt);
    final scaled = input * factor;

    final isNegative = scaled < Decimal.zero;
    final absScaled = isNegative ? -scaled : scaled;
    final half = Decimal.parse('0.5');
    final roundedBigInt = (absScaled + half).toBigInt();
    final signedBigInt = isNegative ? -roundedBigInt : roundedBigInt;

    return (Decimal.fromBigInt(signedBigInt) / factor).toDecimal(
      scaleOnInfinitePrecision: scale,
    );
  }

  /// Calculates a single line item total: quantity * unitPrice
  /// Applies currency half-up rounding.
  static Money calculateLineTotal({
    required Decimal quantity,
    required Money unitPrice,
  }) {
    if (quantity < Decimal.zero) {
      throw ArgumentError('Quantity cannot be negative: $quantity');
    }
    if (unitPrice.isNegative) {
      throw ArgumentError('Unit price cannot be negative: $unitPrice');
    }
    if (quantity == Decimal.zero) {
      return Money.zero(unitPrice.currency);
    }
    final scale = AppCurrencies.get(unitPrice.currency).decimalDigits;
    final rounded = roundHalfUp(unitPrice.value * quantity, scale);
    return Money.fromDecimal(rounded, unitPrice.currency);
  }

  /// Authoritative calculation engine for Invoices (Sales or Purchases)
  static InvoiceCalculationResult calculateInvoice({
    required List<({Decimal quantity, Money unitPrice})> rawItems,
    DiscountType discountType = DiscountType.fixed,
    Decimal? discountValue,
    Decimal? taxRatePercent,
    String currency = AppCurrencies.defaultCurrency,
  }) {
    final scale = AppCurrencies.get(currency).decimalDigits;
    final validTaxRate = taxRatePercent ?? Decimal.zero;
    final validDiscountInput = discountValue ?? Decimal.zero;

    if (validTaxRate < Decimal.zero) {
      throw ArgumentError('Tax rate cannot be negative: $validTaxRate');
    }
    if (validDiscountInput < Decimal.zero) {
      throw ArgumentError(
        'Discount value cannot be negative: $validDiscountInput',
      );
    }

    // 1. Calculate each line total
    final lineItems = <LineItemCalculation>[];
    var subtotalDecimal = Decimal.zero;

    for (final item in rawItems) {
      final total = calculateLineTotal(
        quantity: item.quantity,
        unitPrice: item.unitPrice,
      );
      lineItems.add(
        LineItemCalculation(
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          lineTotal: total,
        ),
      );
      subtotalDecimal += total.value;
    }

    subtotalDecimal = roundHalfUp(subtotalDecimal, scale);
    final subtotal = Money.fromDecimal(subtotalDecimal, currency);

    // 2. Calculate discount amount
    Decimal discountDecimal = Decimal.zero;
    if (validDiscountInput > Decimal.zero && subtotalDecimal > Decimal.zero) {
      if (discountType == DiscountType.fixed) {
        discountDecimal = validDiscountInput > subtotalDecimal
            ? subtotalDecimal
            : validDiscountInput;
      } else {
        // Percentage discount
        final cappedPercent = validDiscountInput > Decimal.fromInt(100)
            ? Decimal.fromInt(100)
            : validDiscountInput;
        final rate = (cappedPercent / Decimal.fromInt(100)).toDecimal(
          scaleOnInfinitePrecision: 8,
        );
        discountDecimal = roundHalfUp(subtotalDecimal * rate, scale);
        if (discountDecimal > subtotalDecimal) {
          discountDecimal = subtotalDecimal;
        }
      }
    }
    discountDecimal = roundHalfUp(discountDecimal, scale);
    final discountAmount = Money.fromDecimal(discountDecimal, currency);

    // 3. Taxable Base = subtotal - discount
    final taxableBaseDecimal = subtotalDecimal > discountDecimal
        ? roundHalfUp(subtotalDecimal - discountDecimal, scale)
        : Decimal.zero;
    final taxableBase = Money.fromDecimal(taxableBaseDecimal, currency);

    // 4. Tax amount = taxableBase * (taxRate / 100)
    Decimal taxDecimal = Decimal.zero;
    if (validTaxRate > Decimal.zero && taxableBaseDecimal > Decimal.zero) {
      final taxMultiplier = (validTaxRate / Decimal.fromInt(100)).toDecimal(
        scaleOnInfinitePrecision: 8,
      );
      taxDecimal = roundHalfUp(taxableBaseDecimal * taxMultiplier, scale);
    }
    final taxAmount = Money.fromDecimal(taxDecimal, currency);

    // 5. Final Total = taxableBase + taxAmount
    final finalTotalDecimal = roundHalfUp(
      taxableBaseDecimal + taxDecimal,
      scale,
    );
    final finalTotal = Money.fromDecimal(finalTotalDecimal, currency);

    return InvoiceCalculationResult(
      items: lineItems,
      subtotal: subtotal,
      discountType: discountType,
      discountInput: validDiscountInput,
      discountAmount: discountAmount,
      taxableBase: taxableBase,
      taxRate: validTaxRate,
      taxAmount: taxAmount,
      finalTotal: finalTotal,
    );
  }

  /// Calculates remaining balance given final total, payments, and return credits
  static Money calculateRemainingBalance({
    required Money finalTotal,
    required Money totalPaid,
    Money? totalReturnCredits,
  }) {
    final credits = totalReturnCredits ?? Money.zero(finalTotal.currency);
    final totalDeductions = totalPaid + credits;

    if (totalDeductions.value >= finalTotal.value) {
      return Money.zero(finalTotal.currency);
    }
    return finalTotal - totalDeductions;
  }

  /// Computes return refund amount for returned items proportional to original net invoice
  static Money calculateReturnRefundAmount({
    required Decimal returnedQuantity,
    required Decimal originalSoldQuantity,
    required Money originalLineTotal,
    required Money originalInvoiceSubtotal,
    required Money originalInvoiceFinalTotal,
  }) {
    if (returnedQuantity <= Decimal.zero ||
        originalSoldQuantity <= Decimal.zero) {
      return Money.zero(originalLineTotal.currency);
    }

    final currency = originalLineTotal.currency;
    final scale = AppCurrencies.get(currency).decimalDigits;

    // Proportion of this line being returned
    final lineRatio = (returnedQuantity / originalSoldQuantity).toDecimal(
      scaleOnInfinitePrecision: 8,
    );
    final returnedLineGross = originalLineTotal.value * lineRatio;

    if (originalInvoiceSubtotal.isZero) {
      return Money.zero(currency);
    }

    // Proportional net value based on original invoice finalTotal vs subtotal
    final netRatio =
        (originalInvoiceFinalTotal.value / originalInvoiceSubtotal.value)
            .toDecimal(scaleOnInfinitePrecision: 8);
    final refundDecimal = roundHalfUp(returnedLineGross * netRatio, scale);

    return Money.fromDecimal(refundDecimal, currency);
  }
}
