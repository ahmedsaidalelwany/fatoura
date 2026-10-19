import 'package:decimal/decimal.dart';
import 'package:fatoura/core/precision/financial_calculator.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money Value Object Tests', () {
    test('Correctly handles decimal additions without floating-point precision drift', () {
      final m1 = Money.fromString('0.10', 'SAR');
      final m2 = Money.fromString('0.20', 'SAR');
      final sum = m1 + m2;
      expect(sum.toStringAsFixed(2), '0.30');
      expect(sum.value, Decimal.parse('0.3'));
    });

    test('Throws on currency mismatch operations', () {
      final sar = Money.fromNum(100, 'SAR');
      final usd = Money.fromNum(100, 'USD');
      expect(() => sar + usd, throwsArgumentError);
    });

    test('Correctly scales and rounds division', () {
      final total = Money.fromNum(100, 'SAR');
      final third = total / Decimal.fromInt(3);
      expect(third.toStringAsFixed(2), '33.33');
    });
  });

  group('FinancialCalculator Engine Tests', () {
    test('Calculates simple invoice without discount or tax', () {
      final items = [
        (quantity: Decimal.fromInt(2), unitPrice: Money.fromNum(50, 'SAR')),
        (quantity: Decimal.fromInt(3), unitPrice: Money.fromNum(10, 'SAR')),
      ];

      final result = FinancialCalculator.calculateInvoice(
        rawItems: items,
        currency: 'SAR',
      );

      expect(result.subtotal.toStringAsFixed(2), '130.00');
      expect(result.discountAmount.toStringAsFixed(2), '0.00');
      expect(result.taxableBase.toStringAsFixed(2), '130.00');
      expect(result.taxAmount.toStringAsFixed(2), '0.00');
      expect(result.finalTotal.toStringAsFixed(2), '130.00');
    });

    test('Applies fixed discount and calculates 15% tax on discounted taxable base', () {
      // Subtotal = 200, Fixed discount = 20 -> Taxable base = 180 -> Tax (15%) = 27 -> Final = 207
      final items = [
        (quantity: Decimal.fromInt(2), unitPrice: Money.fromNum(100, 'SAR')),
      ];

      final result = FinancialCalculator.calculateInvoice(
        rawItems: items,
        discountType: DiscountType.fixed,
        discountValue: Decimal.fromInt(20),
        taxRatePercent: Decimal.fromInt(15),
        currency: 'SAR',
      );

      expect(result.subtotal.toStringAsFixed(2), '200.00');
      expect(result.discountAmount.toStringAsFixed(2), '20.00');
      expect(result.taxableBase.toStringAsFixed(2), '180.00');
      expect(result.taxAmount.toStringAsFixed(2), '27.00');
      expect(result.finalTotal.toStringAsFixed(2), '207.00');
    });

    test(
      'Applies percentage discount correctly and caps discount at subtotal',
      () {
        // Subtotal = 100, Percentage = 10% -> Discount = 10 -> Taxable = 90
        final items = [
          (quantity: Decimal.fromInt(1), unitPrice: Money.fromNum(100, 'SAR')),
        ];

        final result = FinancialCalculator.calculateInvoice(
          rawItems: items,
          discountType: DiscountType.percentage,
          discountValue: Decimal.fromInt(10),
          currency: 'SAR',
        );

        expect(result.discountAmount.toStringAsFixed(2), '10.00');
        expect(result.taxableBase.toStringAsFixed(2), '90.00');
        expect(result.finalTotal.toStringAsFixed(2), '90.00');

        // Attempt 150% discount -> must cap at subtotal 100 and finalTotal = 0
        final cappedResult = FinancialCalculator.calculateInvoice(
          rawItems: items,
          discountType: DiscountType.percentage,
          discountValue: Decimal.fromInt(150),
          currency: 'SAR',
        );
        expect(cappedResult.discountAmount.toStringAsFixed(2), '100.00');
        expect(cappedResult.taxableBase.toStringAsFixed(2), '0.00');
        expect(cappedResult.finalTotal.toStringAsFixed(2), '0.00');
      },
    );

    test(
      'Calculates remaining balance with partial payments and return credits',
      () {
        final total = Money.fromNum(500, 'SAR');
        final paid1 = Money.fromNum(200, 'SAR');
        final credit = Money.fromNum(50, 'SAR');

        final bal = FinancialCalculator.calculateRemainingBalance(
          finalTotal: total,
          totalPaid: paid1,
          totalReturnCredits: credit,
        );

        expect(bal.toStringAsFixed(2), '250.00');

        // Full payment check
        final fullPaid = Money.fromNum(450, 'SAR');
        final zeroBal = FinancialCalculator.calculateRemainingBalance(
          finalTotal: total,
          totalPaid: fullPaid,
          totalReturnCredits: credit,
        );
        expect(zeroBal.isZero, isTrue);
      },
    );

    test('Calculates proportional return refund correctly', () {
      // Sold 4 units at 50 each = 200 line total. Invoice subtotal = 200, final total = 200.
      // Returning 1 unit -> refund = 50.
      final refund = FinancialCalculator.calculateReturnRefundAmount(
        returnedQuantity: Decimal.fromInt(1),
        originalSoldQuantity: Decimal.fromInt(4),
        originalLineTotal: Money.fromNum(200, 'SAR'),
        originalInvoiceSubtotal: Money.fromNum(200, 'SAR'),
        originalInvoiceFinalTotal: Money.fromNum(200, 'SAR'),
      );

      expect(refund.toStringAsFixed(2), '50.00');
    });
  });
}
