import 'package:decimal/decimal.dart';
import 'package:fatoura/core/precision/financial_calculator.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money Value Object Tests', () {
    test('Correctly handles decimal additions without floating-point precision drift', () {
      final m1 = Money.fromString('0.10', 'EGP');
      final m2 = Money.fromString('0.20', 'EGP');
      final sum = m1 + m2;
      expect(sum.toStringAsFixed(2), '0.30');
      expect(sum.value, Decimal.parse('0.3'));
    });

    test('Throws on currency mismatch operations', () {
      final egp = Money.fromNum(100, 'EGP');
      final usd = Money.fromNum(100, 'USD');
      expect(() => egp + usd, throwsArgumentError);
    });

    test('Correctly scales and rounds division', () {
      final total = Money.fromNum(100, 'EGP');
      final third = total / Decimal.fromInt(3);
      expect(third.toStringAsFixed(2), '33.33');
    });
  });

  group('FinancialCalculator Engine Tests', () {
    test('Calculates simple invoice without discount or tax', () {
      final items = [
        (quantity: Decimal.fromInt(2), unitPrice: Money.fromNum(50, 'EGP')),
        (quantity: Decimal.fromInt(3), unitPrice: Money.fromNum(10, 'EGP')),
      ];

      final result = FinancialCalculator.calculateInvoice(
        rawItems: items,
        currency: 'EGP',
      );

      expect(result.subtotal.toStringAsFixed(2), '130.00');
      expect(result.discountAmount.toStringAsFixed(2), '0.00');
      expect(result.taxableBase.toStringAsFixed(2), '130.00');
      expect(result.taxAmount.toStringAsFixed(2), '0.00');
      expect(result.finalTotal.toStringAsFixed(2), '130.00');
    });

    test('Applies fixed discount and calculates 14% tax on discounted taxable base', () {
      // Subtotal = 200, Fixed discount = 20 -> Taxable base = 180 -> Tax (14% Egyptian VAT) = 25.20 -> Final = 205.20
      final items = [
        (quantity: Decimal.fromInt(2), unitPrice: Money.fromNum(100, 'EGP')),
      ];

      final result = FinancialCalculator.calculateInvoice(
        rawItems: items,
        discountType: DiscountType.fixed,
        discountValue: Decimal.fromInt(20),
        taxRatePercent: Decimal.fromInt(14),
        currency: 'EGP',
      );

      expect(result.subtotal.toStringAsFixed(2), '200.00');
      expect(result.discountAmount.toStringAsFixed(2), '20.00');
      expect(result.taxableBase.toStringAsFixed(2), '180.00');
      expect(result.taxAmount.toStringAsFixed(2), '25.20');
      expect(result.finalTotal.toStringAsFixed(2), '205.20');
    });

    test(
      'Applies percentage discount correctly and caps discount at subtotal',
      () {
        // Subtotal = 100, Percentage = 10% -> Discount = 10 -> Taxable = 90
        final items = [
          (quantity: Decimal.fromInt(1), unitPrice: Money.fromNum(100, 'EGP')),
        ];

        final result = FinancialCalculator.calculateInvoice(
          rawItems: items,
          discountType: DiscountType.percentage,
          discountValue: Decimal.fromInt(10),
          currency: 'EGP',
        );

        expect(result.discountAmount.toStringAsFixed(2), '10.00');
        expect(result.taxableBase.toStringAsFixed(2), '90.00');
        expect(result.finalTotal.toStringAsFixed(2), '90.00');

        // Attempt 150% discount -> must cap at subtotal 100 and finalTotal = 0
        final cappedResult = FinancialCalculator.calculateInvoice(
          rawItems: items,
          discountType: DiscountType.percentage,
          discountValue: Decimal.fromInt(150),
          currency: 'EGP',
        );
        expect(cappedResult.discountAmount.toStringAsFixed(2), '100.00');
        expect(cappedResult.taxableBase.toStringAsFixed(2), '0.00');
        expect(cappedResult.finalTotal.toStringAsFixed(2), '0.00');
      },
    );

    test(
      'Calculates remaining balance with partial payments and return credits',
      () {
        final total = Money.fromNum(500, 'EGP');
        final paid1 = Money.fromNum(200, 'EGP');
        final credit = Money.fromNum(50, 'EGP');

        final bal = FinancialCalculator.calculateRemainingBalance(
          finalTotal: total,
          totalPaid: paid1,
          totalReturnCredits: credit,
        );

        expect(bal.toStringAsFixed(2), '250.00');

        // Full payment check
        final fullPaid = Money.fromNum(450, 'EGP');
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
        originalLineTotal: Money.fromNum(200, 'EGP'),
        originalInvoiceSubtotal: Money.fromNum(200, 'EGP'),
        originalInvoiceFinalTotal: Money.fromNum(200, 'EGP'),
      );

      expect(refund.toStringAsFixed(2), '50.00');
    });

    test(
      'FinancialCalculator.roundHalfUp applies deterministic half-up rounding',
      () {
        expect(
          FinancialCalculator.roundHalfUp(Decimal.parse('10.334'), 2),
          Decimal.parse('10.33'),
        );
        expect(
          FinancialCalculator.roundHalfUp(Decimal.parse('10.335'), 2),
          Decimal.parse('10.34'),
        );
        expect(
          FinancialCalculator.roundHalfUp(Decimal.parse('10.336'), 2),
          Decimal.parse('10.34'),
        );

        // Negative values
        expect(
          FinancialCalculator.roundHalfUp(Decimal.parse('-10.335'), 2),
          Decimal.parse('-10.34'),
        );
        expect(
          FinancialCalculator.roundHalfUp(Decimal.parse('-10.334'), 2),
          Decimal.parse('-10.33'),
        );

        // KWD 3 decimals
        expect(
          FinancialCalculator.roundHalfUp(Decimal.parse('1.2345'), 3),
          Decimal.parse('1.235'),
        );
        expect(
          FinancialCalculator.roundHalfUp(Decimal.parse('1.2344'), 3),
          Decimal.parse('1.234'),
        );
      },
    );

    test(
      'Validates and rejects negative quantities, prices, discounts, and taxes',
      () {
        expect(
          () => FinancialCalculator.calculateLineTotal(
            quantity: Decimal.parse('-1'),
            unitPrice: Money.fromNum(10, 'EGP'),
          ),
          throwsArgumentError,
        );

        expect(
          () => FinancialCalculator.calculateLineTotal(
            quantity: Decimal.parse('1'),
            unitPrice: Money.fromNum(-10, 'EGP'),
          ),
          throwsArgumentError,
        );

        expect(
          () => FinancialCalculator.calculateInvoice(
            rawItems: [
              (
                quantity: Decimal.fromInt(1),
                unitPrice: Money.fromNum(100, 'EGP'),
              ),
            ],
            discountValue: Decimal.parse('-5'),
          ),
          throwsArgumentError,
        );

        expect(
          () => FinancialCalculator.calculateInvoice(
            rawItems: [
              (
                quantity: Decimal.fromInt(1),
                unitPrice: Money.fromNum(100, 'EGP'),
              ),
            ],
            taxRatePercent: Decimal.parse('-14'),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'Money.round returns rounded Money instance with half-up arithmetic',
      () {
        final unrounded = Money.fromDecimal(Decimal.parse('15.678'), 'EGP');
        final rounded = unrounded.round();
        expect(rounded.toStringAsFixed(2), '15.68');
        expect(rounded.value, Decimal.parse('15.68'));
      },
    );
  });
}
