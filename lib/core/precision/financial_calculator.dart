import 'package:decimal/decimal.dart';

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

  /// Calculates a single line item total: quantity * unitPrice
  static Money calculateLineTotal({
    required Decimal quantity,
    required Money unitPrice,
  }) {
    if (quantity <= Decimal.zero) {
      return Money.zero(unitPrice.currency);
    }
    return unitPrice * quantity;
  }

  /// Authoritative calculation engine for Invoices (Sales or Purchases)
  static InvoiceCalculationResult calculateInvoice({
    required List<({Decimal quantity, Money unitPrice})> rawItems,
    DiscountType discountType = DiscountType.fixed,
    Decimal? discountValue,
    Decimal? taxRatePercent,
    String currency = 'SAR',
  }) {
    final validTaxRate = taxRatePercent ?? Decimal.zero;
    final validDiscountInput = discountValue ?? Decimal.zero;

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
        final rate = (validDiscountInput / Decimal.fromInt(100)).toDecimal(
          scaleOnInfinitePrecision: 4,
        );
        final calc = subtotalDecimal * rate;
        discountDecimal = calc > subtotalDecimal ? subtotalDecimal : calc;
      }
    }
    final discountAmount = Money.fromDecimal(discountDecimal, currency);

    // 3. Taxable Base = subtotal - discount
    final taxableBaseDecimal = subtotalDecimal > discountDecimal
        ? subtotalDecimal - discountDecimal
        : Decimal.zero;
    final taxableBase = Money.fromDecimal(taxableBaseDecimal, currency);

    // 4. Tax amount = taxableBase * (taxRate / 100)
    Decimal taxDecimal = Decimal.zero;
    if (validTaxRate > Decimal.zero && taxableBaseDecimal > Decimal.zero) {
      final taxMultiplier = (validTaxRate / Decimal.fromInt(100)).toDecimal(
        scaleOnInfinitePrecision: 4,
      );
      taxDecimal = taxableBaseDecimal * taxMultiplier;
    }
    final taxAmount = Money.fromDecimal(taxDecimal, currency);

    // 5. Final Total = taxableBase + taxAmount
    final finalTotalDecimal = taxableBaseDecimal + taxDecimal;
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

    // Proportion of this line being returned
    final lineRatio = (returnedQuantity / originalSoldQuantity).toDecimal(
      scaleOnInfinitePrecision: 6,
    );
    final returnedLineGross = originalLineTotal * lineRatio;

    if (originalInvoiceSubtotal.isZero) {
      return Money.zero(originalLineTotal.currency);
    }

    // Proportional net value based on original invoice finalTotal vs subtotal
    final netRatio =
        (originalInvoiceFinalTotal.value / originalInvoiceSubtotal.value)
            .toDecimal(scaleOnInfinitePrecision: 6);
    final refundDecimal = returnedLineGross.value * netRatio;

    return Money.fromDecimal(refundDecimal, originalLineTotal.currency);
  }
}
