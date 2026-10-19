import 'package:decimal/decimal.dart';
import 'package:fatoura/core/precision/currency.dart';
import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/core/precision/money.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';
import 'package:fatoura/features/shop_setup/domain/entities/shop_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Currency Model & Egyptian Pound (EGP) Tests', () {
    test('EGP is the default currency of the application', () {
      expect(AppCurrencies.defaultCurrency, 'EGP');

      final info = AppCurrencies.get(null);
      expect(info.code, 'EGP');
      expect(info.nameEn, 'Egyptian Pound');
      expect(info.nameAr, 'الجنيه المصري');
      expect(info.majorUnitAr, 'جنيه');
      expect(info.minorUnitAr, 'قرش');
      expect(info.minorUnitFactor, 100);
      expect(info.decimalDigits, 2);
    });

    test('Piastres are treated strictly as minor units of EGP, not a separate currency', () {
      final supportedCodes = AppCurrencies.supportedCurrencyCodes;
      // Piastre must NOT exist as a separate currency option
      expect(supportedCodes.contains('PIASTRE'), isFalse);
      expect(supportedCodes.contains('PT'), isFalse);
      expect(supportedCodes.contains('قرش'), isFalse);
      expect(supportedCodes.contains('EGP'), isTrue);
    });

    test('Exact conversions between Egyptian Pounds and integer Piastres', () {
      // 10000 piastres = 100.00 EGP
      expect(AppCurrencies.piastresToEgp(10000), Decimal.parse('100.00'));
      expect(AppCurrencies.egpToPiastres(Decimal.parse('100.00')), 10000);

      // 2550 piastres = 25.50 EGP
      expect(AppCurrencies.piastresToEgp(2550), Decimal.parse('25.50'));
      expect(AppCurrencies.egpToPiastres(Decimal.parse('25.50')), 2550);

      // 99 piastres = 0.99 EGP
      expect(AppCurrencies.piastresToEgp(99), Decimal.parse('0.99'));
      expect(AppCurrencies.egpToPiastres(Decimal.parse('0.99')), 99);

      // 1 piastre = 0.01 EGP
      expect(AppCurrencies.piastresToEgp(1), Decimal.parse('0.01'));
      expect(AppCurrencies.egpToPiastres(Decimal.parse('0.01')), 1);
    });

    test('Money value object defaults to EGP and handles minor units seamlessly', () {
      final money = Money.fromNum(25.50);
      expect(money.currency, 'EGP');
      expect(money.toPiastres(), 2550);
      expect(money.toMinorUnits(), 2550);

      final fromPiastres = Money.fromPiastres(10000);
      expect(fromPiastres.currency, 'EGP');
      expect(fromPiastres.value, Decimal.parse('100.00'));
      expect(fromPiastres.toStringAsFixed(2), '100.00');
    });

    test('Money.fromString throws ArgumentError on invalid non-numeric strings', () {
      // Empty string parses safely as zero
      expect(Money.fromString('').isZero, isTrue);
      expect(Money.fromString('   ').isZero, isTrue);

      // Valid decimal string parses exactly
      expect(Money.fromString('123.45').value, Decimal.parse('123.45'));

      // Non-numeric strings must throw ArgumentError and NEVER convert silently to zero
      expect(() => Money.fromString('invalid'), throwsArgumentError);
      expect(() => Money.fromString('abc123'), throwsArgumentError);
      expect(() => Money.fromString('NaN'), throwsArgumentError);
    });

    test('Supports 3-decimal digit currencies such as KWD', () {
      final kwd = AppCurrencies.get('KWD');
      expect(kwd.decimalDigits, 3);
      expect(kwd.minorUnitFactor, 1000);

      final moneyKwd = Money.fromNum(12.345, 'KWD');
      expect(moneyKwd.toStringAsFixed(3), '12.345');
      expect(moneyKwd.toMinorUnits(), 12345);

      final formatted = CurrencyFormatter.format(12.345, currency: 'KWD', isArabic: false);
      expect(formatted, 'KWD 12.345');
    });

    test('New shop profile defaults to EGP', () {
      final now = DateTime.now();
      final shop = ShopProfile(
        id: 'shop_1',
        name: 'Supermarket',
        businessType: 'Retail',
        createdAt: now,
        updatedAt: now,
      );

      expect(shop.defaultCurrency, 'EGP');

      final map = shop.toMap();
      expect(map['defaultCurrency'], 'EGP');

      final fromMap = ShopProfile.fromMap(map);
      expect(fromMap.defaultCurrency, 'EGP');
    });
  });

  group('Centralized CurrencyFormatter Tests', () {
    test('Formats EGP correctly for Arabic and English locales', () {
      const amount = 100.0;

      // Arabic: 100.00 ج.م
      final arFormatted = CurrencyFormatter.format(
        amount,
        currency: 'EGP',
        isArabic: true,
      );
      expect(arFormatted, '100.00 ج.م');

      // English: EGP 100.00
      final enFormatted = CurrencyFormatter.format(
        amount,
        currency: 'EGP',
        isArabic: false,
      );
      expect(enFormatted, 'EGP 100.00');
    });

    test('Formats minor units directly with exact decimal output', () {
      // 2550 piastres
      final ar = CurrencyFormatter.formatMinorUnits(
        2550,
        currency: 'EGP',
        isArabic: true,
      );
      expect(ar, '25.50 ج.م');

      final en = CurrencyFormatter.formatMinorUnits(
        2550,
        currency: 'EGP',
        isArabic: false,
      );
      expect(en, 'EGP 25.50');
    });

    test('Provides full localized currency names for settings selection', () {
      final arName = CurrencyFormatter.getLocalizedDisplayName('EGP', isArabic: true);
      expect(arName, 'الجنيه المصري (EGP)');

      final enName = CurrencyFormatter.getLocalizedDisplayName('EGP', isArabic: false);
      expect(enName, 'Egyptian Pound (EGP)');
    });
  });

  group('Historical Document Currency Preservation Tests', () {
    test('Invoice preserves its saved currency when shop profile changes', () {
      final now = DateTime.now();
      // Historical invoice created with EGP
      final invoiceEgp = Invoice(
        id: 'inv_1',
        invoiceNumber: 'Ftr-01.01.2026-0001',
        issueDate: now,
        shopName: 'Test Shop',
        items: const [],
        subtotal: 500.0,
        taxableBase: 500.0,
        finalTotal: 500.0,
        remainingBalance: 0.0,
        currency: 'EGP',
        createdAt: now,
        updatedAt: now,
      );

      // Verify invoice currency is EGP
      expect(invoiceEgp.currency, 'EGP');

      // User changes default shop currency to USD for future invoices
      final updatedShop = ShopProfile(
        id: 'shop_1',
        name: 'Test Shop',
        businessType: 'Retail',
        defaultCurrency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      // The historical invoice's saved currency MUST remain EGP
      expect(invoiceEgp.currency, 'EGP');
      expect(updatedShop.defaultCurrency, 'USD');

      // Formatted output for the historical invoice must use its saved currency EGP, not USD
      final invoiceDisplay = CurrencyFormatter.format(
        invoiceEgp.finalTotal,
        currency: invoiceEgp.currency,
        isArabic: false,
      );
      expect(invoiceDisplay, 'EGP 500.00');
    });
  });
}
